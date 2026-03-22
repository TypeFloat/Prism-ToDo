enum TaskBucket { today, inbox }

enum TaskStatus { todo, done }

enum TaskCaptureState { raw, parsed }

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.bucket,
    this.status = TaskStatus.todo,
    this.captureState = TaskCaptureState.raw,
    this.aiSummary,
  });

  final String id;
  final String title;
  final TaskBucket bucket;
  final TaskStatus status;
  final TaskCaptureState captureState;
  final String? aiSummary;

  bool get isDone => status == TaskStatus.done;
  bool get isParsed => captureState == TaskCaptureState.parsed;

  TaskItem copyWith({
    String? id,
    String? title,
    TaskBucket? bucket,
    TaskStatus? status,
    TaskCaptureState? captureState,
    String? aiSummary,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      bucket: bucket ?? this.bucket,
      status: status ?? this.status,
      captureState: captureState ?? this.captureState,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }
}
