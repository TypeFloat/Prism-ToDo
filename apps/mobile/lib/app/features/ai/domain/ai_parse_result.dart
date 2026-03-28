class AIParseResult {
  const AIParseResult({
    required this.normalizedTitle,
    required this.summary,
    this.deadline,
    this.priority,
    this.location,
    this.notes,
    this.subtasks = const [],
  });

  final String normalizedTitle;
  final String summary;
  final String? deadline;
  final String? priority;
  final String? location;
  final String? notes;
  final List<AIParseSubtask> subtasks;
}

class AIParseSubtask {
  const AIParseSubtask({
    required this.title,
    this.deadline,
    this.priority,
    this.location,
    this.notes,
    this.subtasks = const [],
  });

  final String title;
  final String? deadline;
  final String? priority;
  final String? location;
  final String? notes;
  final List<AIParseSubtask> subtasks;
}
