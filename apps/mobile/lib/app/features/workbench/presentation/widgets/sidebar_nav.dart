import 'package:flutter/material.dart';

import '../../../../app_strings.dart';
import '../workbench_page.dart';

class SidebarNav extends StatelessWidget {
  const SidebarNav({
    super.key,
    required this.selected,
    required this.inboxCount,
    required this.todayCount,
    required this.completedCount,
    required this.calendarCount,
    required this.onSelected,
  });

  final WorkbenchView selected;
  final int inboxCount;
  final int todayCount;
  final int completedCount;
  final int calendarCount;
  final ValueChanged<WorkbenchView> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.appTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(AppStrings.appVersionLabel, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          _NavItem(
            icon: Icons.inbox_outlined,
            label: AppStrings.inbox,
            count: inboxCount,
            selected: selected == WorkbenchView.inbox,
            onTap: () => onSelected(WorkbenchView.inbox),
          ),
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.today_outlined,
            label: AppStrings.today,
            count: todayCount,
            selected: selected == WorkbenchView.today,
            onTap: () => onSelected(WorkbenchView.today),
          ),
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.check_circle_outline,
            label: AppStrings.completed,
            count: completedCount,
            selected: selected == WorkbenchView.completed,
            onTap: () => onSelected(WorkbenchView.completed),
          ),
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.calendar_month_outlined,
            label: AppStrings.calendar,
            count: calendarCount,
            selected: selected == WorkbenchView.calendar,
            onTap: () => onSelected(WorkbenchView.calendar),
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.settings_outlined,
            label: AppStrings.settings,
            count: null,
            selected: selected == WorkbenchView.settings,
            onTap: () => onSelected(WorkbenchView.settings),
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
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

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
              if (count != null)
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
