import 'package:flutter/material.dart';

import '../../../../app_strings.dart';
import '../../../../models/task_item.dart';

class CalendarSection extends StatelessWidget {
  const CalendarSection({
    super.key,
    required this.tasks,
    required this.emptyHint,
  });

  final List<TaskItem> tasks;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final scheduleTasks = tasks.where((task) => task.isScheduled).toList();
    final deadlineTasks = tasks.where((task) => task.isDeadlineOnly || !task.isScheduled).toList();

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
          Text(AppStrings.calendar, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('共 ${tasks.length} 项含时间信息（日程 ${scheduleTasks.length} / 截止 ${deadlineTasks.length}）', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(emptyHint),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  if (scheduleTasks.isNotEmpty) ...[
                    _SectionTitle(title: '日程型任务'),
                    const SizedBox(height: 8),
                    ...scheduleTasks.map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CalendarTaskCard(task: task),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (deadlineTasks.isNotEmpty) ...[
                    _SectionTitle(title: '截止型任务'),
                    const SizedBox(height: 8),
                    ...deadlineTasks.map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CalendarTaskCard(task: task),
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CalendarTaskCard extends StatelessWidget {
  const _CalendarTaskCard({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((task.deadline?.trim().isNotEmpty ?? false)) _TimeChip(label: '截止 ${task.deadline}'),
              if ((task.startAt?.trim().isNotEmpty ?? false)) _TimeChip(label: '开始 ${task.startAt}'),
              if ((task.endAt?.trim().isNotEmpty ?? false)) _TimeChip(label: '结束 ${task.endAt}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
