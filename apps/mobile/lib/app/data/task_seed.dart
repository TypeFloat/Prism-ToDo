import '../app_strings.dart';
import '../models/task_item.dart';

const seedTasks = <TaskItem>[
  TaskItem(
    id: 't1',
    title: AppStrings.sampleTaskReviewToday,
    bucket: TaskBucket.today,
    captureState: TaskCaptureState.parsed,
    aiSummary: AppStrings.sampleTaskReviewTodaySummary,
  ),
  TaskItem(
    id: 't2',
    title: AppStrings.sampleTaskMeetingFollowups,
    bucket: TaskBucket.inbox,
    aiSummary: AppStrings.sampleTaskMeetingFollowupsSummary,
  ),
  TaskItem(
    id: 't3',
    title: AppStrings.sampleTaskDemo,
    bucket: TaskBucket.today,
    status: TaskStatus.done,
    captureState: TaskCaptureState.parsed,
    aiSummary: AppStrings.sampleTaskDemoSummary,
  ),
];
