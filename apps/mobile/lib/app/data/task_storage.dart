import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/task_item.dart';
import 'task_seed.dart';

class TaskStorage {
  const TaskStorage({this.baseDirectory});

  final Directory? baseDirectory;

  Future<List<TaskItem>> loadTasks() async {
    try {
      final file = await _storageFile();
      if (!await file.exists()) {
        await saveTasks(seedTasks);
        return seedTasks;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        await saveTasks(seedTasks);
        return seedTasks;
      }

      final decoded = jsonDecode(content);
      if (decoded is! List) {
        await saveTasks(seedTasks);
        return seedTasks;
      }

      final tasks = decoded
          .whereType<Map>()
          .map((item) => TaskItem.fromJson(Map<String, dynamic>.from(item)))
          .where((task) => task.id.isNotEmpty && task.title.isNotEmpty)
          .toList();

      if (tasks.isEmpty) {
        await saveTasks(seedTasks);
        return seedTasks;
      }

      return tasks;
    } catch (_) {
      return seedTasks;
    }
  }

  Future<void> saveTasks(List<TaskItem> tasks) async {
    final file = await _storageFile();
    final payload = const JsonEncoder.withIndent('  ').convert(
      tasks.map((task) => task.toJson()).toList(),
    );
    await file.writeAsString(payload, flush: true);
  }

  Future<String> storagePath() async {
    final file = await _storageFile();
    return file.path;
  }

  Future<File> _storageFile() async {
    final directory = baseDirectory ?? await getApplicationSupportDirectory();

    final unifiedDir = Directory('${directory.path}/prism_todo');
    if (!await unifiedDir.exists()) {
      await unifiedDir.create(recursive: true);
    }
    final unifiedFile = File('${unifiedDir.path}/tasks.json');
    if (await unifiedFile.exists()) return unifiedFile;

    final legacyDir = Directory('${directory.path}/ai_todo_mobile');
    final legacyFile = File('${legacyDir.path}/tasks.json');
    if (await legacyFile.exists()) {
      await legacyFile.copy(unifiedFile.path);
      return unifiedFile;
    }

    return unifiedFile;
  }
}
