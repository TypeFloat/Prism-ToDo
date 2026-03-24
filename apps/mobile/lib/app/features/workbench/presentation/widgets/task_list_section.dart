import 'package:flutter/material.dart';

import '../../../../app_strings.dart';
import '../../../../models/task_item.dart';

class TaskListSection extends StatelessWidget {
  const TaskListSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.subtaskLookup,
    required this.onToggleDone,
    required this.emptyHint,
    required this.onConfirmParse,
    required this.onMoveToToday,
  });

  final String title;
  final List<TaskItem> tasks;
  final Map<String, List<TaskItem>> subtaskLookup;
  final ValueChanged<String> onToggleDone;
  final String emptyHint;
  final ValueChanged<String> onConfirmParse;
  final ValueChanged<String> onMoveToToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(AppStrings.itemCount(tasks.length), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFF7F8FC), borderRadius: BorderRadius.circular(12)),
              child: Text(emptyHint),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final subtasks = subtaskLookup[task.id] ?? const <TaskItem>[];
                  return _TaskCard(
                    task: task,
                    subtasks: subtasks,
                    onToggleDone: () => onToggleDone(task.id),
                    onConfirmParse: () => onConfirmParse(task.id),
                    onMoveToToday: task.bucket == TaskBucket.inbox && !task.isDone ? () => onMoveToToday(task.id) : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.subtasks,
    required this.onToggleDone,
    required this.onConfirmParse,
    this.onMoveToToday,
  });

  final TaskItem task;
  final List<TaskItem> subtasks;
  final VoidCallback onToggleDone;
  final VoidCallback onConfirmParse;
  final VoidCallback? onMoveToToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = task.isParsed ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest;
    final chipLabel = task.isParsed ? AppStrings.aiParsed : AppStrings.aiPending;
    final summary = task.aiSummary ?? AppStrings.defaultSummary;
    final openSubtasks = subtasks.where((task) => !task.isDone).length;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: const Color(0xFFF7F8FC),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: task.isDone, onChanged: (_) => onToggleDone()),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.bucketLabel(task.bucket.name),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (subtasks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('子任务 ${subtasks.length} 个，未完成 $openSubtasks 个', style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(999)),
                  child: Text(chipLabel, style: theme.textTheme.labelMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary, style: theme.textTheme.bodyMedium),
                  if (task.deadline != null || task.priority != null || task.location != null || task.notes != null) ...[
                    const SizedBox(height: 10),
                    if (task.deadline != null) Text('截止时间：${task.deadline}', style: theme.textTheme.bodySmall),
                    if (task.priority != null) Text('优先级：${task.priority}', style: theme.textTheme.bodySmall),
                    if (task.location != null) Text('地点：${task.location}', style: theme.textTheme.bodySmall),
                    if (task.notes != null) Text('备注：${task.notes}', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (subtasks.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...subtasks.map(
                (subtask) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(subtask.isDone ? Icons.check_circle : Icons.radio_button_unchecked, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(subtask.title, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: task.isParsed ? null : onConfirmParse,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(task.isParsed ? AppStrings.confirmed : AppStrings.confirmParse),
                ),
                if (onMoveToToday != null)
                  FilledButton.tonalIcon(
                    onPressed: onMoveToToday,
                    icon: const Icon(Icons.arrow_forward_outlined),
                    label: const Text(AppStrings.moveToToday),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
