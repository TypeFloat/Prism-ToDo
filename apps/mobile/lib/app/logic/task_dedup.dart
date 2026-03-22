String normalizeTaskTitle(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

bool hasDuplicateTaskTitle({
  required Iterable<String> existingTitles,
  required String candidateTitle,
}) {
  final normalizedCandidate = normalizeTaskTitle(candidateTitle);
  if (normalizedCandidate.isEmpty) return false;

  return existingTitles.any(
    (title) => normalizeTaskTitle(title) == normalizedCandidate,
  );
}
