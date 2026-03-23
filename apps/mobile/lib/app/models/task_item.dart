enum TaskBucket { today, inbox }

enum TaskStatus { todo, done }

enum TaskCaptureState { raw, parsed }

TaskBucket _taskBucketFromName(String value) {
  return TaskBucket.values.firstWhere(
    (item) => item.name == value,
    orElse: () => TaskBucket.inbox,
  );
}

TaskStatus _taskStatusFromName(String value) {
  return TaskStatus.values.firstWhere(
    (item) => item.name == value,
    orElse: () => TaskStatus.todo,
  );
}

TaskCaptureState _taskCaptureStateFromName(String value) {
  return TaskCaptureState.values.firstWhere(
    (item) => item.name == value,
    orElse: () => TaskCaptureState.raw,
  );
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.bucket,
    this.status = TaskStatus.todo,
    this.captureState = TaskCaptureState.raw,
    this.aiSummary,
    this.parentId,
    this.doneAt,
  });

  final String id;
  final String title;
  final TaskBucket bucket;
  final TaskStatus status;
  final TaskCaptureState captureState;
  final String? aiSummary;
  final String? parentId;
  final DateTime? doneAt;

  bool get isDone => status == TaskStatus.done;
  bool get isParsed => captureState == TaskCaptureState.parsed;
  bool get isSubtask => parentId != null;

  TaskItem copyWith({
    String? id,
    String? title,
    TaskBucket? bucket,
    TaskStatus? status,
    TaskCaptureState? captureState,
    String? aiSummary,
    String? parentId,
    DateTime? doneAt,
    bool clearDoneAt = false,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      bucket: bucket ?? this.bucket,
      status: status ?? this.status,
      captureState: captureState ?? this.captureState,
      aiSummary: aiSummary ?? this.aiSummary,
      parentId: parentId ?? this.parentId,
      doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'bucket': bucket.name,
      'status': status.name,
      'captureState': captureState.name,
      'aiSummary': aiSummary,
      'parentId': parentId,
      'doneAt': doneAt?.toIso8601String(),
    };
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      bucket: _taskBucketFromName(json['bucket'] as String? ?? ''),
      status: _taskStatusFromName(json['status'] as String? ?? ''),
      captureState: _taskCaptureStateFromName(json['captureState'] as String? ?? ''),
      aiSummary: json['aiSummary'] as String?,
      parentId: json['parentId'] as String?,
      doneAt: json['doneAt'] == null ? null : DateTime.tryParse(json['doneAt'] as String),
    );
  }
}
