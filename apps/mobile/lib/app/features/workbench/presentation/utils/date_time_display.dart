class DateTimeDisplay {
  const DateTimeDisplay._();

  static DateTime? tryParse(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static String formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String formatHm(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String? dateTextFromRaw(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return formatDate(parsed);
    final text = raw?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? timeTextFromRaw(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return formatHm(parsed);
    return null;
  }
}
