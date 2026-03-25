import 'package:ai_todo_mobile/app/features/workbench/domain/task_service.dart';
import 'package:ai_todo_mobile/app/models/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = TaskService();

  test('auto completion only depends on endAt', () {
    final now = DateTime.parse('2026-03-25T12:00:00+08:00');
    final tasks = [
      const TaskItem(
        id: 'deadline-only',
        title: '截止型任务',
        bucket: TaskBucket.today,
        timeType: TaskTimeType.deadlineOnly,
        deadline: '2026-03-25T10:00:00+08:00',
      ),
      const TaskItem(
        id: 'scheduled-due',
        title: '已到结束时间',
        bucket: TaskBucket.today,
        timeType: TaskTimeType.schedule,
        endAt: '2026-03-25T11:00:00+08:00',
      ),
      const TaskItem(
        id: 'scheduled-future',
        title: '未来结束时间',
        bucket: TaskBucket.today,
        timeType: TaskTimeType.schedule,
        endAt: '2026-03-25T13:00:00+08:00',
      ),
    ];

    final result = service.reconcileAutoCompletion(tasks, now);

    final deadlineOnly = result.firstWhere((t) => t.id == 'deadline-only');
    final scheduledDue = result.firstWhere((t) => t.id == 'scheduled-due');
    final scheduledFuture = result.firstWhere((t) => t.id == 'scheduled-future');

    expect(deadlineOnly.isDone, isFalse, reason: 'deadline 不触发自动完成');
    expect(scheduledDue.isDone, isTrue, reason: 'endAt 到时触发自动完成');
    expect(scheduledFuture.isDone, isFalse, reason: '未来 endAt 不触发自动完成');
  });
}
