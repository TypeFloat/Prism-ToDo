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
import 'widgets/quick_input_bar.dart';
import 'widgets/settings_panel.dart';
import 'widgets/sidebar_nav.dart';
import 'widgets/task_list_section.dart';

enum WorkbenchView { inbox, today, completed, settings }

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({
    super.key,
    this.taskStorage = const TaskStorage(),
    this.settingsStorage = const SettingsStorage(),
    this.aiClient = const OpenAICompatibleClient(),
  });

  final TaskStorage taskStorage;
  final SettingsStorage settingsStorage;
  final OpenAICompatibleClient aiClient;

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  final TextEditingController _controller = TextEditingController();
  final TaskService _taskService = const TaskService();

  WorkbenchView _selected = WorkbenchView.inbox;
  List<TaskItem> _tasks = const [];
  AISettings _settings = const AISettings();
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
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  AppStrings.workbenchSubtitle,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 20),
                                QuickInputBar(
                                  controller: _controller,
                                  onSubmit: _handleQuickAdd,
                                ),
                                const SizedBox(height: 20),
                                Expanded(
                                  child: TaskListSection(
                                    title: AppStrings.bucketLabel(_selected.name),
                                    tasks: _tasksForSelectedView(),
                                    subtaskLookup: _buildSubtaskLookup(),
                                    onToggleDone: _handleToggleDone,
                                    onConfirmParse: _handleConfirmParse,
                                    onMoveToToday: _handleMoveToToday,
                                    emptyHint: _emptyHintForSelectedView(),
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
    final reconciledTasks = _taskService.reconcileAutoCompletion(tasks, DateTime.now());
    if (!mounted) return;
    setState(() {
      _tasks = reconciledTasks;
      _settings = settings;
      _isLoading = false;
    });
    if (_hasTaskStateDiff(tasks, reconciledTasks)) {
      await widget.taskStorage.saveTasks(reconciledTasks);
    }
  }

  Future<void> _persistTasks() => widget.taskStorage.saveTasks(_tasks);
  Future<void> _persistSettings() => widget.settingsStorage.saveSettings(_settings);

  List<TaskItem> _tasksForSelectedView() => _topLevelTasksFor(_selected);

  List<TaskItem> _topLevelTasksFor(WorkbenchView view) {
    final tasks = _tasks.where((task) => task.parentId == null);
    switch (view) {
      case WorkbenchView.today:
        // deadline-only 任务不进入标准时间轴（today 主列表）
        return tasks.where((task) => task.bucket == TaskBucket.today && !task.isDone && !task.isDeadlineOnly).toList();
      case WorkbenchView.completed:
        return tasks.where((task) => task.isDone).toList();
      case WorkbenchView.settings:
        return const [];
      case WorkbenchView.inbox:
        return tasks.where((task) => task.bucket == TaskBucket.inbox && !task.isDone).toList();
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
      case WorkbenchView.settings:
        return '';
      case WorkbenchView.inbox:
        return AppStrings.inboxEmptyHint;
    }
  }

  void _handleQuickAdd() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final isDuplicate = hasDuplicateTaskTitle(
      existingTitles: _tasks.where((task) => task.parentId == null).map((task) => task.title),
      candidateTitle: title,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(AppStrings.duplicateTaskSnackBar)));
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
      final openSubtasks = _tasks.where((task) => task.parentId == taskId && !task.isDone).toList();
      if (openSubtasks.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(AppStrings.completeWithSubtasksTitle),
            content: const Text(AppStrings.completeWithSubtasksMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(AppStrings.cancel)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(AppStrings.confirmCompleteAll)),
            ],
          ),
        );
        if (confirmed != true) return;
        setState(() {
          _tasks = _tasks
              .map((task) {
                if (task.id == taskId || task.parentId == taskId) {
                  return task.copyWith(status: TaskStatus.done, doneAt: DateTime.now());
                }
                return task;
              })
              .toList();
        });
        _persistTasks();
        return;
      }
    }

    setState(() {
      _tasks = _tasks
          .map((task) => task.id == taskId
              ? task.copyWith(
                  status: task.isDone ? TaskStatus.todo : TaskStatus.done,
                  doneAt: task.isDone ? null : DateTime.now(),
                  clearDoneAt: task.isDone,
                )
              : task)
          .toList();
    });
    _persistTasks();
  }

  void _handleConfirmParse(String taskId) async {
    final messenger = ScaffoldMessenger.of(context);
    final target = _tasks.firstWhere((task) => task.id == taskId);
    try {
      final result = await widget.aiClient.parseTask(rawText: target.title, settings: _settings);
      if (!mounted) return;
      setState(() {
        _tasks = _tasks
            .map((task) => task.id == taskId
                ? task.copyWith(
                    title: result.normalizedTitle,
                    captureState: TaskCaptureState.parsed,
                    aiSummary: result.summary,
                    deadline: result.deadline,
                    priority: result.priority,
                    location: result.location,
                    notes: result.notes,
                  )
                : task)
            .toList();
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

  void _handleMoveToToday(String taskId) {
    setState(() {
      _tasks = _tasks
          .map((task) => task.id == taskId
              ? task.copyWith(bucket: TaskBucket.today, captureState: TaskCaptureState.parsed)
              : task)
          .toList();
      _selected = WorkbenchView.today;
    });
    _persistTasks();
  }

  void _handleSettingsChanged(AISettings settings) {
    setState(() {
      _settings = settings;
    });
  }

  void _handleSaveSettings() {
    _persistSettings();
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
