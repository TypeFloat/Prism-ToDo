# Phase 1 Plan — Prism ToDo (macOS-first)

## 结论

第一阶段不再按多端并行推进，统一收口为 **macOS-first**。

Phase 1 只交付一个可演示、可继续扩展的 macOS 桌面基础壳，主路径限定为：

- app shell
- desktop layout
- quick input
- Today
- Inbox

## 1. 目标产物

本阶段目标不是“全平台可运行”，而是以下最小闭环：

1. Flutter 工程可生成并运行 macOS target
2. 主界面具备桌面双栏/分栏布局
3. 支持顶部快捷输入创建任务
4. Today / Inbox 可切换、可展示、可做基础状态流转
5. 代码结构已明确向 macOS 首发收敛

## 2. 范围控制

### In scope
- macOS runner 生成与验证
- 桌面窗口内主工作区布局
- 快捷输入栏
- Today 列表
- Inbox 列表
- 本地 mock 数据和交互占位
- 面向后续状态管理/持久化的目录预留

### Out of scope
- Android / iOS / Web / Windows / Linux 适配推进
- 多端 UI 一致性工作
- 登录、同步、云端协作
- AI 自动规划与复杂 agent 流程
- 项目/标签/筛选器全量产品面
- 真正的数据层落库

## 3. 工程落地策略

### Track A — macOS shell baseline
1. 保持单一 Flutter app 入口
2. 先完成桌面信息架构，不做多端分叉设计
3. 优先验证 macOS 窗口中的导航、列表、输入效率

### Track B — Today / Inbox 主路径
1. Inbox 作为默认捕获池
2. Today 作为当日执行视图
3. 仅支持最基本的创建、查看、状态切换
4. 先保证路径顺，再谈高级组织能力

### Track C — 结构预留
1. `models/` 放任务实体
2. `widgets/` 放桌面壳组件
3. `screens/` 放 macOS 首页工作区
4. 后续再把稳定部分抽到 `packages/`

## 4. 推荐任务顺序

1. docs: 回收所有“多端并行”口径，改成 macOS-first
2. feat: 搭出 macOS 桌面首页骨架
3. feat: 接入快捷输入 + Today/Inbox 切换
4. feat: 增加基础状态变更交互
5. chore: 本地生成并验证 macOS runner
6. chore: 明确下一阶段状态管理与持久化切入点

## 5. 交付标准

满足以下条件即可认为 Phase 1 基线成立：

- 文档口径统一为 macOS-first
- 代码结构能清楚看出 Today / Inbox / quick input 的中心地位
- UI 壳可作为 macOS 演示入口继续迭代
- 没有继续扩散到其他平台的实现包袱

## 6. 风险

- 当前会话未确认 Flutter CLI 是否可用，macOS runner 可能尚未在本地实际生成
- 目录名仍为 `apps/mobile`，语义上会让新成员误以为优先面向移动端，需要在后续阶段评估是否改名为更中性的 `apps/client`
- 目前仍是 mock 数据壳，未接持久化和状态管理

## 7. Git 要求

- 所有变更必须纳入 git
- 建议本轮以文档收口和基础壳调整形成独立提交
- 提交信息建议：`docs: reset phase-1 direction to macos-first` 和 `feat: refocus shell on macos today-inbox flow`
