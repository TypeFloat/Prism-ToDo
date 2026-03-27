import 'package:flutter/material.dart';

import '../../../../app_strings.dart';
import '../../../../models/task_item.dart';

class CalendarSection extends StatelessWidget {
  const CalendarSection({
    super.key,
    required this.tasks,
    required this.emptyHint,
    required this.selectedDate,
    required this.onToday,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final List<TaskItem> tasks;
  final String emptyHint;
  final DateTime selectedDate;
  final VoidCallback onToday;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final scheduleTasks = tasks
        .where((task) => task.isScheduled && _isSameDay(_parse(task.startAt) ?? _parse(task.endAt), selectedDate))
        .toList()
      ..sort((a, b) {
        final aTime = _parse(a.startAt) ?? DateTime(2999);
        final bTime = _parse(b.startAt) ?? DateTime(2999);
        return aTime.compareTo(bTime);
      });

    final deadlineTasks = tasks
        .where((task) => task.isDeadlineOnly && _isSameDay(_parse(task.deadline), selectedDate))
        .toList();

    final overdueTasks = tasks.where((task) {
      if (!task.isDeadlineOnly) return false;
      final deadline = _parse(task.deadline);
      if (deadline == null) return false;
      return deadline.isBefore(_dayStart(DateTime.now())) && !_isSameDay(deadline, selectedDate);
    }).toList();

    final total = scheduleTasks.length + deadlineTasks.length + overdueTasks.length;

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
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(onPressed: onPreviousDay, icon: const Icon(Icons.chevron_left)),
              Text(_formatDay(selectedDate), style: theme.textTheme.titleMedium),
              IconButton(onPressed: onNextDay, icon: const Icon(Icons.chevron_right)),
              const Spacer(),
              OutlinedButton(onPressed: onToday, child: const Text(AppStrings.today)),
            ],
          ),
          const SizedBox(height: 8),
          Text('当日视图：日程 ${scheduleTasks.length} / 截止 ${deadlineTasks.length} / 逾期 ${overdueTasks.length}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          if (total == 0)
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
                    const _SectionTitle(title: '今日日程（时间线）'),
                    const SizedBox(height: 8),
                    ...scheduleTasks.map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CalendarTaskCard(task: task, primaryLabel: _timelineLabel(task)),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (deadlineTasks.isNotEmpty) ...[
                    const _SectionTitle(title: '今日截止'),
                    const SizedBox(height: 8),
                    ...deadlineTasks.map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CalendarTaskCard(task: task, primaryLabel: '截止 ${task.deadline ?? '-'}'),
                        )),
                    const SizedBox(height: 8),
                  ],
                  if (overdueTasks.isNotEmpty) ...[
                    const _SectionTitle(title: '逾期待处理'),
                    const SizedBox(height: 8),
                    ...overdueTasks.map((task) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CalendarTaskCard(task: task, primaryLabel: '逾期 ${task.deadline ?? '-'}'),
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _timelineLabel(TaskItem task) {
    final start = task.startAt?.trim();
    final end = task.endAt?.trim();
    if ((start ?? '').isEmpty && (end ?? '').isEmpty) return '未填写时间';
    if ((end ?? '').isEmpty) return '开始 $start';
    return '$start → $end';
  }

  static DateTime? _parse(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static String _formatDay(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
  const _CalendarTaskCard({required this.task, required this.primaryLabel});

  final TaskItem task;
  final String primaryLabel;

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
          Text(primaryLabel, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
