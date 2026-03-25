import '../../../models/task_item.dart';

class TaskService {
  const TaskService();

  List<TaskItem> reconcileAutoCompletion(List<TaskItem> tasks, DateTime now) {
    return tasks.map((task) {
      if (task.isDone) return task;
      // 仅 endAt 驱动自动完成；deadline 只用于提醒/分区，不触发自动完成。
      final endAt = task.endAt;
      if (endAt == null || endAt.trim().isEmpty) return task;
      final endTime = DateTime.tryParse(endAt);
      if (endTime == null) return task;
      if (endTime.isAfter(now)) return task;
      return task.copyWith(status: TaskStatus.done, doneAt: now);
    }).toList();
  }
}
