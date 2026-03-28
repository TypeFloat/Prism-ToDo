import 'package:flutter/material.dart';

import '../../../app_strings.dart';
import '../../../data/task_storage.dart';
import '../../../logic/task_dedup.dart';
import '../../../models/task_item.dart';
import '../../settings/data/settings_storage.dart';
import '../../settings/domain/ai_settings.dart';
import '../../ai/data/openai_compatible_client.dart';
import '../../ai/domain/ai_request_error.dart';
import '../domain/task_service.dart';
import 'utils/date_time_display.dart';
import 'widgets/calendar_section.dart';
import 'widgets/quick_input_bar.dart';
import 'widgets/settings_panel.dart';
import 'widgets/sidebar_nav.dart';
import 'widgets/task_list_section.dart';

enum WorkbenchView { inbox, today, completed, calendar, settings }

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({
    super.key,
    this.taskStorage = const TaskStorage(),
    this.settingsStorage = const SettingsStorage(),
    this.aiClient = const OpenAICompatibleClient(),
    this.onSettingsChanged,
  });

  final TaskStorage taskStorage;
  final SettingsStorage settingsStorage;
  final OpenAICompatibleClient aiClient;
  final ValueChanged<AISettings>? onSettingsChanged;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  static const List<DropdownMenuItem<String>> _reminderItems = [
    DropdownMenuItem(value: 'none', child: Text(AppStrings.reminderNone)),
    DropdownMenuItem(value: 'at_time', child: Text(AppStrings.reminderAtTime)),
    DropdownMenuItem(value: '5m', child: Text(AppStrings.reminderBefore5m)),
    DropdownMenuItem(value: '15m', child: Text(AppStrings.reminderBefore15m)),
    DropdownMenuItem(value: '30m', child: Text(AppStrings.reminderBefore30m)),
    DropdownMenuItem(value: '1h', child: Text(AppStrings.reminderBefore1h)),
    DropdownMenuItem(value: '1d', child: Text(AppStrings.reminderBefore1d)),
  ];

  final TextEditingController _controller = TextEditingController();
  final TaskService _taskService = const TaskService();

  WorkbenchView _selected = WorkbenchView.inbox;
  List<TaskItem> _tasks = const [];
  AISettings _settings = const AISettings();
  DateTime _calendarDate = DateTime.now();
  bool _isLoading = true;
  bool _isTestingConnection = false;
  String? _lastConnectionResult;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inboxTasks = _topLevelTasksFor(WorkbenchView.inbox);
    final todayTasks = _topLevelTasksFor(WorkbenchView.today);
    final completedTasks = _topLevelTasksFor(WorkbenchView.completed);
    final calendarTasks = _topLevelTasksFor(WorkbenchView.calendar);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Row(
                children: [
                  SidebarNav(
                    selected: _selected,
                    inboxCount: inboxTasks.length,
                    todayCount: todayTasks.length,
                    completedCount: completedTasks.length,
                    calendarCount: calendarTasks.length,
                    onSelected: (view) {
                      setState(() {
                        _selected = view;
                      });
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _selected == WorkbenchView.settings
                          ? SettingsPanel(
                              settings: _settings,
                              onChanged: _handleSettingsChanged,
                              onSave: _handleSaveSettings,
                              onTestConnection: _handleTestConnection,
                              testing: _isTestingConnection,
                              lastTestResult: _lastConnectionResult,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.workbenchTitle,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppStrings.workbenchSubtitle,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 20),
                                if (_selected == WorkbenchView.inbox) ...[
                                  QuickInputBar(
                                    controller: _controller,
                                    onSubmit: _handleQuickAdd,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                Expanded(
                                  child: _selected == WorkbenchView.calendar
                                      ? CalendarSection(
                                          tasks: _tasksForSelectedView(),
                                          emptyHint:
                                              _emptyHintForSelectedView(),
                                          selectedDate: _calendarDate,
                                          onToday: () => setState(
                                            () =>
                                                _calendarDate = DateTime.now(),
                                          ),
                                          onPreviousDay: () => setState(
                                            () => _calendarDate = _calendarDate
                                                .subtract(
                                                  const Duration(days: 1),
                                                ),
                                          ),
                                          onNextDay: () => setState(
                                            () => _calendarDate = _calendarDate
                                                .add(const Duration(days: 1)),
                                          ),
                                        )
                                      : TaskListSection(
                                          title:
                                              _selected == WorkbenchView.today
                                              ? _todaySectionTitle()
                                              : AppStrings.bucketLabel(
                                                  _selected.name,
                                                ),
                                          tasks: _tasksForSelectedView(),
                                          subtaskLookup: _buildSubtaskLookup(),
                                          onToggleDone: _handleToggleDone,
                                          onDelete: _handleDeleteTask,
                                          onEdit: _handleEditTask,
                                          onConfirmParse: _handleConfirmParse,
                                          onPostponeToTomorrow:
                                              _handlePostponeToTomorrow,
                                          onEditInfoField: _handleEditInfoField,
                                          emptyHint:
                                              _emptyHintForSelectedView(),
                                        ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _loadState() async {
    final tasks = await widget.taskStorage.loadTasks();
    final settings = await widget.settingsStorage.loadSettings();
    final reconciledTasks = _taskService.reconcileAutoCompletion(
      tasks,
      DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _tasks = reconciledTasks;
      _settings = settings;
      _isLoading = false;
    });
    widget.onSettingsChanged?.call(settings);
    if (_hasTaskStateDiff(tasks, reconciledTasks)) {
      await widget.taskStorage.saveTasks(reconciledTasks);
    }
  }

  Future<void> _persistTasks() => widget.taskStorage.saveTasks(_tasks);
  Future<void> _persistSettings() =>
      widget.settingsStorage.saveSettings(_settings);

  List<TaskItem> _tasksForSelectedView() => _topLevelTasksFor(_selected);

  List<TaskItem> _topLevelTasksFor(WorkbenchView view) {
    final tasks = _tasks.where((task) => task.parentId == null);
    switch (view) {
      case WorkbenchView.today:
        final todayTasks = tasks
            .where((task) => task.bucket == TaskBucket.today && !task.isDone)
            .toList();
        todayTasks.sort((a, b) => _todayRank(a).compareTo(_todayRank(b)));
        return todayTasks;
      case WorkbenchView.completed:
        return tasks.where((task) => task.isDone).toList();
      case WorkbenchView.calendar:
        bool hasParsableTime(TaskItem task) {
          final deadline = DateTime.tryParse(task.deadline?.trim() ?? '');
          final startAt = DateTime.tryParse(task.startAt?.trim() ?? '');
          final endAt = DateTime.tryParse(task.endAt?.trim() ?? '');
          return deadline != null || startAt != null || endAt != null;
        }

        return tasks
            .where((task) => !task.isDone)
            .where(hasParsableTime)
            .toList();
      case WorkbenchView.settings:
        return const [];
      case WorkbenchView.inbox:
        return tasks
            .where((task) => task.bucket == TaskBucket.inbox && !task.isDone)
            .toList();
    }
  }

  Map<String, List<TaskItem>> _buildSubtaskLookup() {
    final map = <String, List<TaskItem>>{};
    for (final task in _tasks.where((item) => item.parentId != null)) {
      map.putIfAbsent(task.parentId!, () => []).add(task);
    }
    return map;
  }

  bool _hasTaskStateDiff(List<TaskItem> before, List<TaskItem> after) {
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      final b = before[i];
      final a = after[i];
      if (b.id != a.id || b.status != a.status || b.doneAt != a.doneAt) {
        return true;
      }
    }
    return false;
  }

  String _emptyHintForSelectedView() {
    switch (_selected) {
      case WorkbenchView.today:
        return AppStrings.todayEmptyHint;
      case WorkbenchView.completed:
        return AppStrings.completedEmptyHint;
      case WorkbenchView.calendar:
        return AppStrings.calendarEmptyHint;
      case WorkbenchView.settings:
        return '';
      case WorkbenchView.inbox:
        return AppStrings.inboxEmptyHint;
    }
  }

  String _todaySectionTitle() {
    final tasks = _tasks.where(
      (task) =>
          task.parentId == null &&
          task.bucket == TaskBucket.today &&
          !task.isDone,
    );
    final schedule = tasks.where((task) => task.isScheduled).length;
    final deadline = tasks
        .where((task) => task.isDeadlineOnly && !_isOverdue(task))
        .length;
    final overdue = tasks.where((task) => _isOverdue(task)).length;
    return '${AppStrings.today}（日程 $schedule / 截止 $deadline / 逾期 $overdue）';
  }

  int _todayRank(TaskItem task) {
    if (task.isScheduled) return 0;
    if (_isOverdue(task)) return 2;
    if (task.isDeadlineOnly) return 1;
    return 3;
  }

  bool _isOverdue(TaskItem task) {
    final deadline = DateTime.tryParse(task.deadline?.trim() ?? '');
    if (deadline == null) return false;
    return deadline.isBefore(DateTime.now());
  }

  void _handleQuickAdd() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final isDuplicate = hasDuplicateTaskTitle(
      existingTitles: _tasks
          .where((task) => task.parentId == null)
          .map((task) => task.title),
      candidateTitle: title,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.duplicateTaskSnackBar)),
        );
      return;
    }

    setState(() {
      _tasks = [
        TaskItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          bucket: TaskBucket.inbox,
          aiSummary: AppStrings.placeholderParse(title),
        ),
        ..._tasks,
      ];
      _selected = WorkbenchView.inbox;
      _controller.clear();
    });
    _persistTasks();
  }

  Future<void> _handleToggleDone(String taskId) async {
    final target = _tasks.firstWhere((task) => task.id == taskId);
    if (!target.isDone) {
      final openSubtasks = _tasks
          .where((task) => task.parentId == taskId && !task.isDone)
          .toList();
      if (openSubtasks.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(AppStrings.completeWithSubtasksTitle),
            content: const Text(AppStrings.completeWithSubtasksMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(AppStrings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(AppStrings.confirmCompleteAll),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        setState(() {
          _tasks = _tasks.map((task) {
            if (task.id == taskId || task.parentId == taskId) {
              return task.copyWith(
                status: TaskStatus.done,
                doneAt: DateTime.now(),
              );
            }
            return task;
          }).toList();
        });
        _persistTasks();
        return;
      }
    }

    setState(() {
      _tasks = _tasks
          .map(
            (task) => task.id == taskId
                ? task.copyWith(
                    status: task.isDone ? TaskStatus.todo : TaskStatus.done,
                    doneAt: task.isDone ? null : DateTime.now(),
                    clearDoneAt: task.isDone,
                  )
                : task,
          )
          .toList();
    });
    _persistTasks();
  }

  Future<void> _handleEditTask(String taskId) async {
    final original = _tasks.firstWhere((task) => task.id == taskId);

    final titleController = TextEditingController(text: original.title);
    final notesController = TextEditingController(text: original.notes ?? '');
    DateTime? startValue = DateTimeDisplay.tryParse(original.startAt);
    DateTime? endValue = DateTimeDisplay.tryParse(original.endAt);
    DateTime? dueValue = DateTimeDisplay.tryParse(original.deadline);

    String taskType = original.isScheduled
        ? 'schedule'
        : (original.isDeadlineOnly ? 'deadline' : 'todo');
    String reminder = original.reminder ?? 'none';

    Future<DateTime?> pickDate(
      BuildContext pageContext,
      DateTime? current,
    ) async {
      final now = DateTime.now();
      final initial = current ?? now;
      final date = await showDatePicker(
        context: pageContext,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (!pageContext.mounted || date == null) return null;
      final timeBase = current ?? DateTime(now.year, now.month, now.day, 9);
      return DateTime(
        date.year,
        date.month,
        date.day,
        timeBase.hour,
        timeBase.minute,
      );
    }

    Future<DateTime?> pickTime(
      BuildContext pageContext,
      DateTime? current,
    ) async {
      final base = current ?? DateTime.now();
      final time = await showTimePicker(
        context: pageContext,
        initialTime: TimeOfDay.fromDateTime(base),
      );
      if (time == null) return null;
      return DateTime(base.year, base.month, base.day, time.hour, time.minute);
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('编辑任务'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: '标题'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: taskType,
                    decoration: const InputDecoration(labelText: '任务类型'),
                    items: const [
                      DropdownMenuItem(value: 'todo', child: Text('普通待办')),
                      DropdownMenuItem(value: 'schedule', child: Text('日程型任务')),
                      DropdownMenuItem(value: 'deadline', child: Text('截止型任务')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setLocalState(() => taskType = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (taskType == 'schedule') ...[
                    _DateTimePickerTile(
                      label: '开始',
                      value: startValue,
                      requiredField: true,
                      onPickDate: () async {
                        final picked = await pickDate(context, startValue);
                        if (picked == null) return;
                        setLocalState(() => startValue = picked);
                      },
                      onPickTime: () async {
                        final picked = await pickTime(context, startValue);
                        if (picked == null) return;
                        setLocalState(() => startValue = picked);
                      },
                      onClear: () => setLocalState(() => startValue = null),
                    ),
                    const SizedBox(height: 10),
                    _DateTimePickerTile(
                      label: '结束',
                      value: endValue,
                      onPickDate: () async {
                        final picked = await pickDate(context, endValue);
                        if (picked == null) return;
                        setLocalState(() => endValue = picked);
                      },
                      onPickTime: () async {
                        final picked = await pickTime(context, endValue);
                        if (picked == null) return;
                        setLocalState(() => endValue = picked);
                      },
                      onClear: () => setLocalState(() => endValue = null),
                    ),
                  ] else if (taskType == 'deadline') ...[
                    _DateTimePickerTile(
                      label: '截止',
                      value: dueValue,
                      requiredField: true,
                      onPickDate: () async {
                        final picked = await pickDate(context, dueValue);
                        if (picked == null) return;
                        setLocalState(() => dueValue = picked);
                      },
                      onPickTime: () async {
                        final picked = await pickTime(context, dueValue);
                        if (picked == null) return;
                        setLocalState(() => dueValue = picked);
                      },
                      onClear: () => setLocalState(() => dueValue = null),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (taskType == 'todo')
                    Text(
                      '普通待办默认不设置提醒，请先切换为日程型或截止型。',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: reminder,
                      decoration: const InputDecoration(
                        labelText: AppStrings.reminderLabel,
                      ),
                      items: _reminderItems,
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => reminder = value);
                      },
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: '备注'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final title = titleController.text.trim();
    if (title.isEmpty) return;

    final startAt = startValue?.toIso8601String() ?? '';
    final endAt = endValue?.toIso8601String() ?? '';
    final deadline = dueValue?.toIso8601String() ?? '';
    final notes = notesController.text.trim();

    if (taskType == 'schedule' && startValue == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('日程型任务必须填写开始时间')));
      return;
    }

    if (taskType == 'deadline' && dueValue == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('截止型任务必须填写截止日期')));
      return;
    }

    setState(() {
      _tasks = _tasks.map((task) {
        if (task.id != taskId) return task;

        if (taskType == 'schedule') {
          return task.copyWith(
            title: title,
            bucket: TaskBucket.today,
            timeType: TaskTimeType.schedule,
            startAt: startAt,
            endAt: endAt.isEmpty ? '' : endAt,
            deadline: '',
            notes: notes.isEmpty ? '' : notes,
            reminder: reminder,
          );
        }

        if (taskType == 'deadline') {
          return task.copyWith(
            title: title,
            bucket: TaskBucket.today,
            timeType: TaskTimeType.deadlineOnly,
            startAt: '',
            endAt: '',
            deadline: deadline.isEmpty ? null : deadline,
            notes: notes.isEmpty ? '' : notes,
            reminder: reminder,
          );
        }

        return task.copyWith(
          title: title,
          bucket: TaskBucket.inbox,
          timeType: TaskTimeType.none,
          startAt: '',
          endAt: '',
          deadline: '',
          notes: notes.isEmpty ? '' : notes,
          reminder: 'none',
        );
      }).toList();
    });

    await _persistTasks();
  }

  Future<void> _handleDeleteTask(String taskId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('确认删除该任务？其子任务也会一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _tasks = _tasks
          .where((task) => task.id != taskId && task.parentId != taskId)
          .toList();
    });
    await _persistTasks();
  }

  void _handleConfirmParse(String taskId) async {
    final messenger = ScaffoldMessenger.of(context);
    final target = _tasks.firstWhere((task) => task.id == taskId);
    try {
      final result = await widget.aiClient.parseTask(
        rawText: target.title,
        settings: _settings,
      );
      if (!mounted) return;
      setState(() {
        _tasks = _tasks.map((task) {
          if (task.id != taskId) return task;
          final hasDeadline = (result.deadline?.trim().isNotEmpty ?? false);
          return task.copyWith(
            title: result.normalizedTitle,
            captureState: TaskCaptureState.parsed,
            aiSummary: result.summary,
            deadline: result.deadline,
            priority: result.priority,
            location: result.location,
            notes: result.notes,
            bucket: hasDeadline ? TaskBucket.today : task.bucket,
            timeType: hasDeadline ? TaskTimeType.deadlineOnly : task.timeType,
          );
        }).toList();
      });
      _persistTasks();
    } on AIRequestError catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('AI 解析失败：$error')));
    }
  }

  void _handlePostponeToTomorrow(String taskId) {
    setState(() {
      _tasks = _tasks.map((task) {
        if (task.id != taskId) return task;
        return task.copyWith(
          bucket: TaskBucket.inbox,
          startAt: _plusOneDayText(task.startAt),
          endAt: _plusOneDayText(task.endAt),
          deadline: _plusOneDayText(task.deadline),
        );
      }).toList();
      _selected = WorkbenchView.inbox;
    });
    _persistTasks();
  }

  String? _plusOneDayText(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return value;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return value;
    return parsed.add(const Duration(days: 1)).toIso8601String();
  }

  Future<void> _handleEditInfoField(String taskId, TaskInfoField field) async {
    switch (field) {
      case TaskInfoField.date:
        return _editTaskDate(taskId);
      case TaskInfoField.time:
        return _editTaskTime(taskId);
      case TaskInfoField.priority:
        return _editTaskPriority(taskId);
    }
  }

  Future<void> _editTaskDate(String taskId) async {
    final task = _tasks.firstWhere((item) => item.id == taskId);
    final current = _primaryDateTime(task) ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || pickedDate == null) return;
    final merged = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      current.hour,
      current.minute,
    );
    await _applyPrimaryDateTime(taskId, merged);
  }

  Future<void> _editTaskTime(String taskId) async {
    final task = _tasks.firstWhere((item) => item.id == taskId);
    final current = _primaryDateTime(task) ?? DateTime.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (!mounted || pickedTime == null) return;
    final merged = DateTime(
      current.year,
      current.month,
      current.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    await _applyPrimaryDateTime(taskId, merged);
  }

  Future<void> _editTaskPriority(String taskId) async {
    final task = _tasks.firstWhere((item) => item.id == taskId);
    final priorityController = TextEditingController(text: task.priority ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑优先级'),
        content: TextField(
          controller: priorityController,
          decoration: const InputDecoration(labelText: '优先级（如：高/中/低）'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final priority = priorityController.text.trim();
    setState(() {
      _tasks = _tasks
          .map(
            (item) => item.id == taskId
                ? item.copyWith(priority: priority.isEmpty ? '' : priority)
                : item,
          )
          .toList();
    });
    await _persistTasks();
  }

  DateTime? _primaryDateTime(TaskItem task) {
    if (task.isScheduled) {
      return DateTimeDisplay.tryParse(task.startAt) ??
          DateTimeDisplay.tryParse(task.endAt);
    }
    if (task.isDeadlineOnly) {
      return DateTimeDisplay.tryParse(task.deadline);
    }
    return DateTimeDisplay.tryParse(task.deadline) ??
        DateTimeDisplay.tryParse(task.startAt) ??
        DateTimeDisplay.tryParse(task.endAt);
  }

  Future<void> _applyPrimaryDateTime(String taskId, DateTime value) async {
    final iso = value.toIso8601String();
    setState(() {
      _tasks = _tasks.map((item) {
        if (item.id != taskId) return item;
        if (item.isScheduled) {
          return item.copyWith(
            bucket: TaskBucket.today,
            timeType: TaskTimeType.schedule,
            startAt: iso,
          );
        }
        return item.copyWith(
          bucket: TaskBucket.today,
          timeType: TaskTimeType.deadlineOnly,
          deadline: iso,
          startAt: '',
          endAt: '',
        );
      }).toList();
    });
    await _persistTasks();
  }

  void _handleSettingsChanged(AISettings settings) {
    setState(() {
      _settings = settings;
    });
    widget.onSettingsChanged?.call(settings);
  }

  void _handleSaveSettings() {
    _persistSettings();
    widget.onSettingsChanged?.call(_settings);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(AppStrings.settingsSaved)));
  }

  void _handleTestConnection() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isTestingConnection = true;
      _lastConnectionResult = null;
    });

    final result = await widget.aiClient.testConnection(settings: _settings);
    if (!mounted) return;

    setState(() {
      _isTestingConnection = false;
      _lastConnectionResult = result.message;
    });

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message)));
  }
}

class _DateTimePickerTile extends StatelessWidget {
  const _DateTimePickerTile({
    required this.label,
    required this.value,
    required this.onPickDate,
    required this.onPickTime,
    required this.onClear,
    this.requiredField = false,
  });

  final String label;
  final DateTime? value;
  final Future<void> Function() onPickDate;
  final Future<void> Function() onPickTime;
  final VoidCallback onClear;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    final dateText = value == null ? '未设置' : DateTimeDisplay.formatDate(value!);
    final timeText = value == null ? '--:--' : DateTimeDisplay.formatHm(value!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(requiredField ? '$label（必填）' : '$label（可选）'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('日期 $dateText'),
              ),
              OutlinedButton.icon(
                onPressed: onPickTime,
                icon: const Icon(Icons.schedule_outlined),
                label: Text('时间 $timeText'),
              ),
              TextButton(onPressed: onClear, child: const Text('清空')),
            ],
          ),
        ],
      ),
    );
  }
}
