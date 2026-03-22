import 'package:flutter/material.dart';

import '../app_strings.dart';
import '../models/task_item.dart';

class SidebarNav extends StatelessWidget {
  const SidebarNav({
    super.key,
    required this.selected,
    required this.todayCount,
    required this.inboxCount,
    required this.onSelected,
  });

  final TaskBucket selected;
  final int todayCount;
  final int inboxCount;
  final ValueChanged<TaskBucket> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.appTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            AppStrings.phaseTag,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          _NavItem(
            icon: Icons.today_outlined,
            label: AppStrings.today,
            count: todayCount,
            selected: selected == TaskBucket.today,
            onTap: () => onSelected(TaskBucket.today),
          ),
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.inbox_outlined,
            label: AppStrings.inbox,
            count: inboxCount,
            selected: selected == TaskBucket.inbox,
            onTap: () => onSelected(TaskBucket.inbox),
          ),
          const Spacer(),
          Text(
            AppStrings.phaseScopeHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(label)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
