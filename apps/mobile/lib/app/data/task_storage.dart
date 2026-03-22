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
    final appDirectory = Directory('${directory.path}/ai_todo_mobile');
    if (!await appDirectory.exists()) {
      await appDirectory.create(recursive: true);
    }
    return File('${appDirectory.path}/tasks.json');
  }
}
