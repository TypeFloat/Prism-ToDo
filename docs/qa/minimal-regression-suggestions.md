# Minimal Regression Suggestions — Quick Input / Move to Today / Confirm parse

## 目标

给 macOS-first Phase 1 补最小回归建议，优先覆盖当前主路径里最容易出问题的 3 个点：

1. Quick Input 防重复创建
2. Move to Today
3. Confirm parse

当前实现观察（基于 `apps/mobile/lib/app/screens/macos_home_page.dart`）：

- Quick Input 仅做 `trim + empty guard`
- 当前**没有重复创建保护**
- `Move to Today` 会把任务直接改为 `today + parsed`
- `Confirm parse` 会把任务改为 `parsed`

这意味着当前最小风险不是“功能缺失”，而是“状态流转过于宽松、容易重复或误通过”。

---

## 1) Quick Input 防重复创建

### 最小回归目标
同一原始输入不应因快速重复点击 / 回车连发，在 Inbox 顶部生成多条完全相同任务。

### 建议先覆盖的场景

#### Case QI-01 同文本重复点击
步骤：
1. 输入 `Draft weekly plan`
2. 连续点击两次 `Capture to Inbox`

期望：
- 理想：只创建 1 条
- 当前若产品尚未做防重：应至少记录为已知缺口，不可误判通过

#### Case QI-02 回车 + 点击连发
步骤：
1. 输入 `Call design team`
2. 先按 Enter，再立即点按钮

期望：
- 最终仅 1 条新任务

#### Case QI-03 前后空格归一化
步骤：
1. 输入 `  Send invoice  `
2. 创建后再次输入 `Send invoice`

期望：
- 若防重按归一化文本判断，应识别为重复
- 若当前未实现，也应在 QA 记录中明确为缺口

### 最低实现建议（给 Dev）
可先做**会话级最小防重**：
- 提交时对文本做 `trim`
- 用最近一次提交文本 + 短时间窗口（如 500ms~1000ms）去重
- 或直接按当前任务列表中“同 bucket + 同规范化 title”拦截重复

### 回归结论标准
- 不能因双击/连按造成重复记录
- 如果产品允许同名任务，也要至少挡住“同一次交互里的误重复创建”

---

## 2) Move to Today

### 最小回归目标
确保任务从 Inbox 移动到 Today 时，位置、计数、状态同步正确。

### 建议先覆盖的场景

#### Case MT-01 基础迁移
步骤：
1. 在 Inbox 选一条 raw task
2. 点击 `Move to Today`

期望：
- Inbox 列表中该任务消失
- Today 列表中出现该任务
- 侧栏计数同步变化
- 当前选中视图切到 Today

#### Case MT-02 已解析状态联动
步骤：
1. 选一条未 parsed 的 Inbox 任务
2. 点击 `Move to Today`

期望：
- 任务进入 Today
- capture state 自动变为 `parsed`
- summary 不为空（至少补 placeholder）

#### Case MT-03 重复移动保护
步骤：
1. 将某任务移动到 Today
2. 再次查看该任务操作区

期望：
- 不应继续显示 `Move to Today`
- 不应能重复迁移出重复副本

### 回归结论标准
- 任务只移动一次
- 不产生重复项
- 计数、列表、选中视图三者一致

---

## 3) Confirm parse

### 最小回归目标
确保 `Confirm parse` 真正改变任务解析状态，且不会造成二次确认异常。

### 建议先覆盖的场景

#### Case CP-01 Raw → Parsed
步骤：
1. 选择一条 raw Inbox 任务
2. 点击 `Confirm parse`

期望：
- 状态从 `AI pending` 变为 `AI parsed`
- 按钮置灰或文案变为 `Confirmed`
- summary 不为空

#### Case CP-02 已解析幂等
步骤：
1. 对已 parsed 任务观察操作区

期望：
- `Confirm parse` 不可再次触发
- 不应因重复点击导致异常刷新或重复状态变更

#### Case CP-03 不影响 bucket
步骤：
1. 在 Inbox 对 raw task 点击 `Confirm parse`

期望：
- 任务仍留在 Inbox
- 仅解析状态改变，不自动移动到 Today

### 回归结论标准
- Confirm parse 只负责“确认解析”
- Move to Today 只负责“调度到 Today”
- 两个动作职责不能混淆

---

## 推荐最小测试层级

### 手工回归
当前阶段必须有，适合首跑验证。

### Widget test（Phase 1 建议尽快补）
建议至少补 3 组：
1. Quick Input 创建 + 防重复
2. Confirm parse 状态切换
3. Move to Today 后列表/计数变化

---

## QA 对当前实现的判断

### 已具备
- 主路径动作存在
- Confirm parse / Move to Today 的基本状态流转已接上

### 主要缺口
- Quick Input 防重复当前未实现
- 自动化回归当前未建立
- `Move to Today` 直接附带 parsed 语义，后续需确认是否符合产品预期

---

## 建议优先级

### P0
- Quick Input 最小防重
- macOS 首跑后补 1 轮人工回归

### P1
- 增加 widget test 覆盖 3 个关键动作
- 明确 `Confirm parse` 与 `Move to Today` 的职责边界是否最终定稿
