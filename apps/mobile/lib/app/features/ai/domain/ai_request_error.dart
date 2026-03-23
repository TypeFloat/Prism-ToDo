class AIRequestError implements Exception {
  const AIRequestError(this.message);

  final String message;

  @override
  String toString() => message;
}
