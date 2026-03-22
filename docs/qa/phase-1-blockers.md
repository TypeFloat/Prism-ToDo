# Phase 1 QA Blockers — macOS-first

更新时间：2026-03-20
目录基线：`/Users/return0/Code/ai-todo`

## 总结
按当前 Phase 1 主链路（Quick Input → 确认/降级 → Inbox → Move to Today → Today）评估，仓库现状仍是 **桌面 UI 壳 + 本地 mock 列表**，尚不能作为该主链路的可提测版本。

## 阻断项

### B1. Quick Input 归属规则错误
- 严重级别：P0
- 期望：Quick Input 默认是 capture lane，先进入 Inbox
- 现状：新建任务写入当前选中的列表（Today 或 Inbox）
- 代码位置：`apps/mobile/lib/app/screens/macos_home_page.dart`
- 代码依据：`_handleQuickAdd()` 中 `bucket: _selected`
- 影响：当用户停留在 Today 时，快速输入会绕过 Inbox，破坏主链路定义
- 处理建议：
  - 将 Quick Input 默认落点固定为 Inbox
  - 若未来支持“直接进 Today”，必须有显式确认，不应复用默认路径

### B2. 缺少 Confirm / Degrade 机制
- 严重级别：P0
- 期望：对输入内容有明确确认/降级策略，模糊任务应可降级入 Inbox
- 现状：纯文本直接创建，无解析结果、无确认、无降级
- 影响：主链路中的“确认/降级”完全不可测
- 处理建议：
  - 至少先做一个可见的占位流程：`直接收进 Inbox` 为默认，`Move to Today` 为后续明确动作
  - 若短期不做智能解析，PM/Dev 需把 Phase 1 口径改成“无解析，仅人工流转”

### B3. 缺少 Move to Today 操作
- 严重级别：P0
- 期望：Inbox 中的任务可明确移动到 Today
- 现状：只有 done 切换，没有 bucket 迁移
- 影响：Inbox → Today 主链路断裂
- 处理建议：
  - 在任务行提供 `Move to Today` / `Move back to Inbox`
  - 迁移后同步更新列表与计数

### B4. 缺少误解析恢复/改归属能力
- 严重级别：P1
- 期望：错误归类后，用户可自行恢复
- 现状：没有任何 bucket 改归属能力
- 影响：一旦归类错误，用户无恢复路径
- 处理建议：
  - 最低要求：支持双向移动 Today ↔ Inbox
  - 若后续有解析结果展示，应保留“撤销/改回 Inbox”入口

### B5. 存在重复创建风险
- 严重级别：P1
- 期望：单次提交只创建一条任务
- 现状：无防抖、无幂等、无提交中禁用
- 风险场景：回车与点击 Add 近同时发生、用户双击 Add
- 影响：mock 阶段即可出现重复任务；后续接持久化/API 后会放大
- 处理建议：
  - 增加提交中保护或短时间去重
  - 提交后立即禁用按钮至本次创建结束
  - 对同一输入事件生成客户端 request id

## 非阻断但需记录

### N1. 默认选中 Today 与主链路不一致
- 现状：首页默认 `_selected = TaskBucket.today`
- 风险：用户第一眼更像在执行清单，不像在 capture lane
- 建议：若主链路强调 capture first，可评估默认落在 Inbox，或保持 Today 默认但确保 Quick Input 始终入 Inbox

### N2. 缺少自动化测试工件
- 现状：未见 `test/widget_test.dart` 或对应 QA 自动化
- 风险：归属规则、迁移、重复创建等高风险路径无法回归验证
- 建议：补最小 widget tests 覆盖创建、归属、迁移、计数

### N3. 包名与 Phase 1 口径不一致
- 现状：`apps/mobile`、`ai_todo_mobile`
- 风险：持续误导成员按移动端理解目录
- 建议：短期用 README/QA 文档明确“这是 macOS-first shell”；中期评估更名为更中性的 app 名称

## 目录错误纠偏
- 本轮确认真实工作目录是：`/Users/return0/Code/ai-todo`
- 若 Dev 之前基于 `/Users/return0/.openclaw/workspace/project-team/proj-coordinator` 或其共享目录理解为代码仓库，那是错误目录
- 正确做法：
  1. 所有代码检查、修复、测试、提交均以 `/Users/return0/Code/ai-todo` 为准
  2. 协作文档可汇总到共享目录，但不得替代真实 repo 检查
  3. 修复时请直接引用 repo 内真实文件路径，避免再次在协调工作区产出“假工件”

## 提测结论
- 结论：**当前不建议按 Phase 1 主链路提测**
- 原因：P0 阻断项 B1/B2/B3 未闭合，核心链路尚未形成可演示闭环
