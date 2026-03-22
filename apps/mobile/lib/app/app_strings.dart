class AppStrings {
  const AppStrings._();

  static const appTitle = 'Prism ToDo';
  static const phaseTag = 'Phase 1 · macOS 优先';
  static const phaseScopeHint = 'Phase 1 当前仅包含“今天”和“收件箱”。';

  static const today = '今天';
  static const inbox = '收件箱';

  static const macosShellTitle = 'macOS 桌面工作台';
  static const macosShellSubtitle = 'Phase 1 路径：快速记录 → 收件箱 → 确认解析 → 移入今天 → 今天。';

  static const quickInputTitle = '快速记录';
  static const quickInputHint = '所有输入都会先进入收件箱。AI 解析在 Phase 1 中先以本地占位逻辑呈现。';
  static const quickInputPlaceholder = '输入原始任务、想法或待跟进事项…';
  static const captureToInbox = '记录到收件箱';

  static const duplicateTaskSnackBar = '这个任务已经存在于收件箱或今天。';
  static const todayEmptyHint = '今天列表还是空的，可以先把收件箱里已明确的任务移进来。';
  static const inboxEmptyHint = '收件箱为空，先用快速记录把原始任务收进来。';

  static const itemCountSuffix = '项';
  static const aiParsed = 'AI 已解析';
  static const aiPending = 'AI 待确认';
  static const defaultSummary = '占位说明：推断意图、整理措辞，确认后再决定是否安排。';
  static const confirmed = '已确认';
  static const confirmParse = '确认解析';
  static const moveToToday = '移到今天';

  static const sampleTaskReviewToday = '梳理今天的优先任务';
  static const sampleTaskReviewTodaySummary = '这是今天的聚焦任务，完成前保持在“今天”列表中。';
  static const sampleTaskMeetingFollowups = '整理会议纪要里的后续事项';
  static const sampleTaskMeetingFollowupsSummary = '下一步可拆成 2~3 个明确的跟进行动。';
  static const sampleTaskDemo = '准备 macOS 优先版本演示';
  static const sampleTaskDemoSummary = '演示内容已准备完成，可作为已完成样例。';

  static String bucketLabel(bool isToday) => isToday ? today : inbox;
  static String itemCount(int count) => '$count $itemCountSuffix';
  static String placeholderParse(String title) => '占位解析：“$title”看起来像一个单一的下一步动作。先确认措辞，再决定是否放进“今天”。';
}
