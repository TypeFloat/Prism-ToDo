import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/ai_settings.dart';

class SettingsStorage {
  const SettingsStorage({this.baseDirectory});

  final Directory? baseDirectory;

  Future<AISettings> loadSettings() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        const defaults = AISettings();
        await saveSettings(defaults);
        return defaults;
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        const defaults = AISettings();
        await saveSettings(defaults);
        return defaults;
      }
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return const AISettings();
      }
      return AISettings.fromJson(decoded);
    } catch (_) {
      return const AISettings();
    }
  }

  Future<void> saveSettings(AISettings settings) async {
    final file = await _settingsFile();
    final payload = const JsonEncoder.withIndent('  ').convert(settings.toJson());
    await file.writeAsString(payload, flush: true);
  }

  Future<File> _settingsFile() async {
    final directory = baseDirectory ?? await getApplicationSupportDirectory();

    final unifiedDir = Directory('${directory.path}/prism_todo');
    if (!await unifiedDir.exists()) {
      await unifiedDir.create(recursive: true);
    }
    final unifiedFile = File('${unifiedDir.path}/settings.json');
    if (await unifiedFile.exists()) return unifiedFile;

    final legacyDir = Directory('${directory.path}/ai_todo_mobile');
    final legacyFile = File('${legacyDir.path}/settings.json');
    if (await legacyFile.exists()) {
      await legacyFile.copy(unifiedFile.path);
      return unifiedFile;
    }

    return unifiedFile;
  }
}
