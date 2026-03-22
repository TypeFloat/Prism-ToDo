# Phase 1 Smoke Cases — macOS-first

更新时间：2026-03-20
目录基线：`/Users/return0/Code/ai-todo`

## 适用主链路
Quick Input → 确认/降级 → Inbox → Move to Today → Today

> 说明：当前仓库实现仅覆盖了部分链路。以下 smoke case 同时包含“已具备的验证项”和“Phase 1 目标应具备但当前缺失的验证项”。

## Smoke Case 01 — App shell 启动
- 前置：Flutter/macOS runner 可正常启动
- 步骤：打开应用
- 预期：
  - 左侧存在 Today / Inbox 导航
  - 主区存在 Quick Input
  - 默认进入一个明确列表视图
- 当前代码状态：**部分满足**
- 备注：UI 壳存在，但未见仓库内 macOS runner/测试工件，需本机实际跑通确认

## Smoke Case 02 — Quick Input 基础创建
- 前置：应用已打开
- 步骤：在 Quick Input 输入 `Buy milk`，按回车或点击 Add
- 预期：
  - 创建 1 条新任务
  - 输入框清空
  - 新任务出现在预期的捕获位置
- 当前代码状态：**部分满足**
- 当前实现：会创建、会清空输入框
- 阻断说明：当前创建位置跟随当前选中列表，不符合“Quick Input 默认进 Inbox”的主链路定义

## Smoke Case 03 — Quick Input 默认归属到 Inbox
- 前置：位于 Today 视图
- 步骤：在 Today 视图中使用 Quick Input 创建 `Plan demo`
- 预期：
  - 新任务先进入 Inbox
  - Today 不应因为快速捕获而直接新增未确认任务
- 当前代码状态：**不满足 / 阻断**
- 代码依据：`_handleQuickAdd()` 中 `bucket: _selected`

## Smoke Case 04 — 确认/降级机制
- 前置：输入存在“可直接入 Today”与“应降级入 Inbox”的不同文案
- 步骤：分别输入明确当天执行任务、模糊想法、含歧义文本
- 预期：
  - 系统有明确确认或降级策略
  - 模糊/误解析内容可回退到 Inbox
- 当前代码状态：**缺失 / 阻断**
- 备注：当前只有纯文本新增，没有解析、确认、降级或恢复流程

## Smoke Case 05 — Inbox 移动到 Today
- 前置：Inbox 中存在待办
- 步骤：将一条 Inbox 任务移动到 Today
- 预期：
  - 该任务从 Inbox 消失
  - Today 中出现该任务
  - 计数同步更新
- 当前代码状态：**缺失 / 阻断**
- 备注：当前只有 done 切换，无 bucket 迁移操作

## Smoke Case 06 — Today / Inbox 归属唯一性
- 前置：存在至少 1 条任务
- 步骤：检查任务从 Inbox → Today 后的展示
- 预期：
  - 同一任务任一时刻只属于一个 bucket
  - 不会同时在 Today 和 Inbox 双重出现
- 当前代码状态：**模型层可满足，交互层未覆盖**
- 备注：`TaskItem.bucket` 为单值字段，但缺少迁移操作的 UI/测试验证

## Smoke Case 07 — 误解析后的人工恢复
- 前置：系统发生错误归类（例如本应 Inbox 却进 Today）
- 步骤：用户执行恢复/改归属
- 预期：
  - 用户可把任务改回 Inbox
  - 恢复动作对用户可见、可理解
- 当前代码状态：**缺失 / 阻断**

## Smoke Case 08 — 防重复创建
- 前置：Quick Input 中输入同一文本
- 步骤：连续按 Enter、再快速点击 Add；或双击 Add
- 预期：
  - 单次提交只创建 1 条记录
  - UI 层应避免重复触发
- 当前代码状态：**存在风险**
- 风险依据：当前无提交中状态、无幂等键、无去抖/节流保护

## Smoke Case 09 — Done 切换不影响 bucket
- 前置：Today 或 Inbox 中存在任务
- 步骤：勾选完成 / 取消完成
- 预期：
  - 只切换完成状态
  - 不改变 Today / Inbox 归属
- 当前代码状态：**满足**

## Smoke Case 10 — 空状态文案
- 前置：Today 或 Inbox 为空
- 步骤：切换列表
- 预期：
  - Today / Inbox 均展示正确空状态提示
  - 文案能引导下一步操作
- 当前代码状态：**满足**

## 当前 smoke 结论
- 已具备：基础桌面壳、Today/Inbox 切换、列表计数、基础创建、done 切换、空状态
- 未具备：确认/降级、误解析恢复、Move to Today、默认 Inbox 捕获、防重复创建
- 因此：**当前版本不满足按 Phase 1 主链路提测**
