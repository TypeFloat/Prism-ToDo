import 'dart:io';

import 'package:ai_todo_mobile/app/data/task_storage.dart';
import 'package:ai_todo_mobile/app/models/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task storage saves and reloads task mutations', () async {
    final tempDir = await Directory.systemTemp.createTemp('ai_todo_storage_test');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final storage = TaskStorage(baseDirectory: tempDir);

    final original = await storage.loadTasks();
    expect(original, isNotEmpty);

    final updated = [
      TaskItem(
        id: 'persist-1',
        title: '验证本地持久化',
        bucket: TaskBucket.today,
        status: TaskStatus.done,
        captureState: TaskCaptureState.parsed,
        aiSummary: '已从收件箱移到今天，并标记完成。',
        reminder: '15m',
      ),
      const TaskItem(
        id: 'persist-2',
        title: '重启后恢复任务列表',
        bucket: TaskBucket.inbox,
        captureState: TaskCaptureState.raw,
      ),
    ];

    await storage.saveTasks(updated);
    final reloaded = await storage.loadTasks();

    expect(reloaded.length, 2);
    expect(reloaded.first.title, '验证本地持久化');
    expect(reloaded.first.bucket, TaskBucket.today);
    expect(reloaded.first.status, TaskStatus.done);
    expect(reloaded.first.captureState, TaskCaptureState.parsed);
    expect(reloaded.first.reminder, '15m');
    expect(reloaded.last.title, '重启后恢复任务列表');
    expect(reloaded.last.bucket, TaskBucket.inbox);

    final storageFilePath = await storage.storagePath();
    expect(await File(storageFilePath).exists(), isTrue);
  });
}
