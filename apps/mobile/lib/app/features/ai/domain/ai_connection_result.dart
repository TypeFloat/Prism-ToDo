class AIConnectionResult {
  const AIConnectionResult({
    required this.success,
    required this.message,
    this.statusCode,
    this.rawResponse,
  });

  final bool success;
  final String message;
  final int? statusCode;
  final String? rawResponse;
}
