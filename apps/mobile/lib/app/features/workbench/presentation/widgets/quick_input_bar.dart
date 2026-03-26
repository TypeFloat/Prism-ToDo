import 'package:flutter/material.dart';

import '../../../../app_strings.dart';

class QuickInputBar extends StatelessWidget {
  const QuickInputBar({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.quickInputTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(AppStrings.quickInputHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: AppStrings.quickInputPlaceholder,
                    prefixIcon: const Icon(Icons.bolt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.add_task_outlined),
                label: const Text(AppStrings.captureToInbox),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
