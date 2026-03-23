class AIParseResult {
  const AIParseResult({
    required this.normalizedTitle,
    required this.summary,
    this.deadline,
    this.priority,
    this.location,
  });

  final String normalizedTitle;
  final String summary;
  final String? deadline;
  final String? priority;
  final String? location;
}
