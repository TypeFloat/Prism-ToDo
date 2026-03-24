class AppStrings {
  const AppStrings._();

  static const appTitle = 'Prism ToDo';
  static const appVersionLabel = 'v0.2.0';

  static const today = '今天';
  static const inbox = '收件箱';
  static const completed = '已完成';
  static const settings = '设置';

  static const workbenchTitle = 'Prism ToDo';
  static const workbenchSubtitle = '收集、整理、完成任务；AI 能力在设置完成后可逐步启用。';

  static const quickInputTitle = '快速记录';
  static const quickInputHint = '新任务默认先进入收件箱。';
  static const quickInputPlaceholder = '输入任务、想法、待办事项…';
  static const captureToInbox = '加入收件箱';

  static const duplicateTaskSnackBar = '这个任务已经存在于收件箱或今天。';
  static const todayEmptyHint = '今天暂无未完成任务。';
  static const inboxEmptyHint = '收件箱暂无未完成任务。';
  static const completedEmptyHint = '还没有已完成任务。';

  static const itemCountSuffix = '项';
  static const aiParsed = 'AI 已解析';
  static const aiPending = 'AI 待确认';
  static const defaultSummary = 'AI 解析说明：可补充截止时间、优先级、地点等信息。';
  static const confirmed = '已确认';
  static const confirmParse = '确认解析';
  static const moveToToday = '移到今天';

  static const settingsTitle = '设置';
  static const settingsSubtitle = 'Phase 2 先落本地配置与 OpenAI 兼容骨架，暂不要求真实联网。';
  static const aiFeatureToggle = '启用 AI 解析';
  static const aiAdvancedMode = '高级模式';
  static const aiBaseUrl = 'Base URL';
  static const aiApiKey = 'API Key / Token';
  static const aiModel = 'Model';
  static const aiEnvFallbackHint = '软件内配置优先；为空时回退到环境变量 PRISM_TODO_AI_URL / PRISM_TODO_AI_TOKEN。';
  static const aiTemperature = 'Temperature';
  static const aiTimeout = '超时时间（秒）';
  static const testConnection = '测试连接';
  static const saveSettings = '保存设置';
  static const settingsSaved = '设置已保存到本地。';
  static const connectionCheckPlaceholder = '当前仅完成 OpenAI 兼容接口骨架；真实连接等待负责人填入参数后验证。';

  static const completeWithSubtasksTitle = '还有未完成子任务';
  static const completeWithSubtasksMessage = '该任务仍有未完成子任务。确认后将父任务和所有子任务一起标记为完成。';
  static const confirmCompleteAll = '全部完成';
  static const cancel = '取消';

  static const sampleTaskReviewToday = '梳理今天的优先任务';
  static const sampleTaskReviewTodaySummary = '聚焦任务，适合保留在今天视图中。';
  static const sampleTaskMeetingFollowups = '整理会议纪要里的后续事项';
  static const sampleTaskMeetingFollowupsSummary = '可继续拆成多个可执行动作。';
  static const sampleTaskDemo = '准备 Prism ToDo 演示';
  static const sampleTaskDemoSummary = '保留一条已完成样例，验证 Completed 视图。';
  static const sampleSubTaskOne = '确认演示顺序';
  static const sampleSubTaskTwo = '检查截图与文案';

  static String bucketLabel(String key) {
    switch (key) {
      case 'today':
        return today;
      case 'completed':
        return completed;
      case 'settings':
        return settings;
      default:
        return inbox;
    }
  }

  static String itemCount(int count) => '$count $itemCountSuffix';
  static String placeholderParse(String title) => 'AI 解析：“$title”可进一步提取截止时间、优先级、地点等元信息。';
}
