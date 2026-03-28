import 'package:flutter/material.dart';

import '../../../../app_strings.dart';
import '../../../../models/task_item.dart';
import '../utils/date_time_display.dart';

enum TaskInfoField { date, time, priority }

class TaskListSection extends StatelessWidget {
  const TaskListSection({
    super.key,
    required this.title,
    required this.tasks,
    required this.subtaskLookup,
    required this.onToggleDone,
    required this.onDelete,
    required this.onEdit,
    required this.emptyHint,
    required this.onConfirmParse,
    required this.onPostponeToTomorrow,
    required this.onEditInfoField,
  });

  final String title;
  final List<TaskItem> tasks;
  final Map<String, List<TaskItem>> subtaskLookup;
  final ValueChanged<String> onToggleDone;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onEdit;
  final String emptyHint;
  final ValueChanged<String> onConfirmParse;
  final ValueChanged<String> onPostponeToTomorrow;
  final void Function(String taskId, TaskInfoField field) onEditInfoField;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            AppStrings.itemCount(tasks.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
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
                    onDelete: () => onDelete(task.id),
                    onEdit: () => onEdit(task.id),
                    onConfirmParse: () => onConfirmParse(task.id),
                    onPostponeToTomorrow:
                        task.bucket == TaskBucket.today && !task.isDone
                        ? () => onPostponeToTomorrow(task.id)
                        : null,
                    onEditInfoField: (field) => onEditInfoField(task.id, field),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

enum _TaskMenuAction { edit, confirmParse, postpone, delete }

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.subtasks,
    required this.onToggleDone,
    required this.onDelete,
    required this.onEdit,
    required this.onConfirmParse,
    required this.onEditInfoField,
    this.onPostponeToTomorrow,
  });

  final TaskItem task;
  final List<TaskItem> subtasks;
  final VoidCallback onToggleDone;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onConfirmParse;
  final VoidCallback? onPostponeToTomorrow;
  final ValueChanged<TaskInfoField> onEditInfoField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = task.isParsed
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final chipLabel = task.isParsed
        ? AppStrings.aiParsed
        : AppStrings.aiPending;
    final summary = (task.aiSummary?.trim().isNotEmpty ?? false)
        ? task.aiSummary!.trim()
        : AppStrings.defaultSummary;
    final priority = _nonEmpty(task.priority);
    final location = _nonEmpty(task.location);
    final notes = _nonEmpty(task.notes);
    final reminder = _reminderLabel(task.reminder);
    final deadlineState = _deadlineState(task.deadline);
    final openSubtasks = subtasks.where((task) => !task.isDone).length;
    final dateText = _dateText(task);
    final timeText = _timeText(task);
    final isTodayCard = task.bucket == TaskBucket.today && !task.isDone;

    final card = Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.surfaceContainerHigh,
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
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.bucketLabel(task.bucket.name),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (subtasks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '子任务 ${subtasks.length} 个，未完成 $openSubtasks 个',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(chipLabel, style: theme.textTheme.labelMedium),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: isTodayCard ? null : onEdit,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isTodayCard
                    ? _TodayInfoPanel(
                        summary: summary,
                        dateText: dateText ?? '未设置日期',
                        timeText: timeText ?? '--:--',
                        priorityText: priority ?? '未设置优先级',
                        deadlineState: deadlineState,
                        onEditInfoField: onEditInfoField,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(summary, style: theme.textTheme.bodyMedium),
                          if (dateText != null ||
                              timeText != null ||
                              priority != null ||
                              location != null ||
                              notes != null ||
                              reminder != null ||
                              deadlineState != null) ...[
                            const SizedBox(height: 10),
                            if (dateText != null)
                              Text(
                                '日期：$dateText',
                                style: theme.textTheme.bodySmall,
                              ),
                            if (timeText != null)
                              Text(
                                '时间：$timeText',
                                style: theme.textTheme.bodySmall,
                              ),
                            if (deadlineState != null)
                              Text(
                                deadlineState,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: deadlineState.startsWith('已逾期')
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.tertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (reminder != null)
                              Text(
                                '提醒：$reminder',
                                style: theme.textTheme.bodySmall,
                              ),
                            if (priority != null)
                              Text(
                                '优先级：$priority',
                                style: theme.textTheme.bodySmall,
                              ),
                            if (location != null)
                              Text(
                                '地点：$location',
                                style: theme.textTheme.bodySmall,
                              ),
                            if (notes != null)
                              Text(
                                '备注：$notes',
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ],
                      ),
              ),
            ),
            if (subtasks.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...subtasks.map(
                (subtask) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        subtask.isDone
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subtask.title,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!isTodayCard) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: task.isParsed ? null : onConfirmParse,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      task.isParsed
                          ? AppStrings.confirmed
                          : AppStrings.confirmParse,
                    ),
                  ),
                  if (onPostponeToTomorrow != null)
                    OutlinedButton.icon(
                      onPressed: onPostponeToTomorrow,
                      icon: const Icon(Icons.event_repeat_outlined),
                      label: const Text(AppStrings.postponeToTomorrow),
                    ),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (!isTodayCard) return card;

    return GestureDetector(
      onSecondaryTapDown: (details) => _showContextMenu(context, details),
      onLongPress: onEdit,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    TapDownDetails details,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) return;

    final x = details.globalPosition.dx;
    final y = details.globalPosition.dy;
    final action = await showMenu<_TaskMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        x,
        y,
        overlay.size.width - x,
        overlay.size.height - y,
      ),
      items: [
        const PopupMenuItem(value: _TaskMenuAction.edit, child: Text('编辑任务')),
        PopupMenuItem(
          value: _TaskMenuAction.confirmParse,
          enabled: !task.isParsed,
          child: Text(
            task.isParsed ? AppStrings.confirmed : AppStrings.confirmParse,
          ),
        ),
        if (onPostponeToTomorrow != null)
          const PopupMenuItem(
            value: _TaskMenuAction.postpone,
            child: Text(AppStrings.postponeToTomorrow),
          ),
        const PopupMenuItem(value: _TaskMenuAction.delete, child: Text('删除')),
      ],
    );

    switch (action) {
      case _TaskMenuAction.edit:
        onEdit();
        break;
      case _TaskMenuAction.confirmParse:
        if (!task.isParsed) onConfirmParse();
        break;
      case _TaskMenuAction.postpone:
        onPostponeToTomorrow?.call();
        break;
      case _TaskMenuAction.delete:
        onDelete();
        break;
      case null:
        break;
    }
  }

  String? _dateText(TaskItem item) {
    final parsed = DateTimeDisplay.tryParse(_timeSourceRaw(item));
    if (parsed != null) return DateTimeDisplay.formatDate(parsed);
    return _nonEmpty(_timeSourceRaw(item));
  }

  String? _timeText(TaskItem item) {
    final parsed = DateTimeDisplay.tryParse(_timeSourceRaw(item));
    if (parsed != null) return DateTimeDisplay.formatHm(parsed);
    return null;
  }

  String? _timeSourceRaw(TaskItem item) {
    if (item.isScheduled) {
      return _nonEmpty(item.startAt) ?? _nonEmpty(item.endAt);
    }
    if (item.isDeadlineOnly) return _nonEmpty(item.deadline);
    return _nonEmpty(item.deadline) ??
        _nonEmpty(item.startAt) ??
        _nonEmpty(item.endAt);
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _reminderLabel(String? reminder) {
    switch ((reminder ?? 'none').trim()) {
      case 'at_time':
        return AppStrings.reminderAtTime;
      case '5m':
        return AppStrings.reminderBefore5m;
      case '15m':
        return AppStrings.reminderBefore15m;
      case '30m':
        return AppStrings.reminderBefore30m;
      case '1h':
        return AppStrings.reminderBefore1h;
      case '1d':
        return AppStrings.reminderBefore1d;
      default:
        return null;
    }
  }

  String? _deadlineState(String? deadlineText) {
    final deadline = DateTimeDisplay.tryParse(deadlineText);
    if (deadline == null) return null;
    final now = DateTime.now();
    if (deadline.isBefore(now)) return '已逾期';
    final diff = deadline.difference(now);
    if (diff <= const Duration(hours: 24)) return '24小时内到期';
    return null;
  }
}

class _TodayInfoPanel extends StatelessWidget {
  const _TodayInfoPanel({
    required this.summary,
    required this.dateText,
    required this.timeText,
    required this.priorityText,
    required this.deadlineState,
    required this.onEditInfoField,
  });

  final String summary;
  final String dateText;
  final String timeText;
  final String priorityText;
  final String? deadlineState;
  final ValueChanged<TaskInfoField> onEditInfoField;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _InfoCell(
                label: '日期',
                value: dateText,
                onTap: () => onEditInfoField(TaskInfoField.date),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoCell(
                label: '时间',
                value: timeText,
                onTap: () => onEditInfoField(TaskInfoField.time),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InfoCell(
                label: '优先级',
                value: priorityText,
                onTap: () => onEditInfoField(TaskInfoField.priority),
              ),
            ),
          ],
        ),
        if (deadlineState != null) ...[
          const SizedBox(height: 8),
          Text(
            deadlineState!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: deadlineState!.startsWith('已逾期')
                  ? theme.colorScheme.error
                  : theme.colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
