import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../data/task_storage.dart';
import '../logic/task_dedup.dart';
import '../models/task_item.dart';
import '../widgets/quick_input_bar.dart';
import '../widgets/sidebar_nav.dart';
import '../widgets/task_list_section.dart';

class MacosHomePage extends StatefulWidget {
  const MacosHomePage({super.key, this.taskStorage = const TaskStorage()});

  final TaskStorage taskStorage;

  @override
  State<MacosHomePage> createState() => _MacosHomePageState();
}

class _MacosHomePageState extends State<MacosHomePage> {
  final TextEditingController _controller = TextEditingController();

  TaskBucket _selected = TaskBucket.inbox;
  List<TaskItem> _tasks = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayCount = _tasks.where((task) => task.bucket == TaskBucket.today).length;
    final inboxCount = _tasks.where((task) => task.bucket == TaskBucket.inbox).length;
    final visibleTasks = _tasks.where((task) => task.bucket == _selected).toList();
    final selectedLabel = AppStrings.bucketLabel(_selected == TaskBucket.today);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: Row(
          children: [
            SidebarNav(
              selected: _selected,
              todayCount: todayCount,
              inboxCount: inboxCount,
              onSelected: (bucket) {
                setState(() {
                  _selected = bucket;
                });
              },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.macosShellTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.macosShellSubtitle,
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
                        title: selectedLabel,
                        tasks: visibleTasks,
                        onToggleDone: _handleToggleDone,
                        onConfirmParse: _handleConfirmParse,
                        onMoveToToday: _handleMoveToToday,
                        emptyHint: _selected == TaskBucket.today
                            ? AppStrings.todayEmptyHint
                            : AppStrings.inboxEmptyHint,
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

  Future<void> _loadTasks() async {
    final tasks = await widget.taskStorage.loadTasks();
    if (!mounted) return;

    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _persistTasks() async {
    await widget.taskStorage.saveTasks(_tasks);
  }

  void _handleQuickAdd() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    final isDuplicate = hasDuplicateTaskTitle(
      existingTitles: _tasks.map((task) => task.title),
      candidateTitle: title,
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(AppStrings.duplicateTaskSnackBar),
          ),
        );
      return;
    }

    setState(() {
      _tasks = [
        TaskItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          bucket: TaskBucket.inbox,
          aiSummary: _buildPlaceholderSummary(title),
        ),
        ..._tasks,
      ];
      _selected = TaskBucket.inbox;
      _controller.clear();
    });
    _persistTasks();
  }

  void _handleToggleDone(String taskId) {
    setState(() {
      _tasks = _tasks
          .map(
            (task) => task.id == taskId
                ? task.copyWith(
                    status: task.isDone ? TaskStatus.todo : TaskStatus.done,
                  )
                : task,
          )
          .toList();
    });
    _persistTasks();
  }

  void _handleConfirmParse(String taskId) {
    setState(() {
      _tasks = _tasks
          .map(
            (task) => task.id == taskId
                ? task.copyWith(
                    captureState: TaskCaptureState.parsed,
                    aiSummary: task.aiSummary ?? _buildPlaceholderSummary(task.title),
                  )
                : task,
          )
          .toList();
    });
    _persistTasks();
  }

  void _handleMoveToToday(String taskId) {
    setState(() {
      _tasks = _tasks
          .map(
            (task) => task.id == taskId
                ? task.copyWith(
                    bucket: TaskBucket.today,
                    captureState: TaskCaptureState.parsed,
                    aiSummary: task.aiSummary ?? _buildPlaceholderSummary(task.title),
                  )
                : task,
          )
          .toList();
      _selected = TaskBucket.today;
    });
    _persistTasks();
  }

  String _buildPlaceholderSummary(String title) {
    return AppStrings.placeholderParse(title);
  }
}
