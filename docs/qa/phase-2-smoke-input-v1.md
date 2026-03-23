# Prism ToDo Phase 2 第一轮 Smoke 提测输入（v1）

## 版本标识
- 分支：`dev/phase2-core-workbench`
- 版本：`0.2.0+1`

## 可验范围（本轮）
1. 新边栏导航
   - Inbox / Today / Completed / Settings 可进入
2. 任务视图规则
   - Inbox / Today 默认隐藏已完成任务
   - Completed 显示已完成任务
3. 父子任务完成确认链路
   - 父任务存在未完成子任务时，点击完成出现确认弹窗
4. 设置页与 AI 配置
   - AI 开关、高级模式、Base URL、Token、Model、Temperature、Timeout 可保存
   - “测试连接”可触发并返回成功/失败提示
5. OpenAI 兼容解析链路
   - 支持 `/v1/chat/completions`
   - 解析字段：title / deadline / priority / location / notes
   - 字段可回写并在任务卡片中展示
6. 配置优先级
   - 软件内配置优先
   - 软件内为空时回退环境变量：`PRISM_TODO_AI_URL` / `PRISM_TODO_AI_TOKEN`

## 暂不验范围（本轮不作为通过门槛）
- 多轮对话质量/提示词优化
- 复杂子任务管理（新增/编辑/层级操作）
- AI 解析准确率统计与大样本评估
- 密钥安全增强（如 Keychain）
- 跨平台一致性（仅先测 macOS）

## 启动 / 运行方式
```bash
cd ~/Code/ai-todo/apps/mobile
flutter pub get
flutter run -d macos
```

如需验证“环境变量兜底”链路，建议使用已加载 `~/.zshrc` 的方式启动：
```bash
zsh -ic 'cd ~/Code/ai-todo/apps/mobile && flutter run -d macos'
```

## 设置页高级模式与测试连接操作步骤
1. 打开侧边栏 `设置`
2. 开启 `启用 AI 解析`
3. 开启 `高级模式`
4. 填写（或留空以走环境变量）：
   - Base URL
   - API Key / Token
   - Model
5. 点击 `保存设置`
6. 点击 `测试连接`
7. 预期：出现成功提示（例如“连接成功：ok”）或明确错误提示（非黑盒失败）

## AI 真实样例输入与预期结果
### 样例 A（字段完整）
输入：
- 明天下午3点前把项目周报发给Alice，优先级高，在公司处理，备注：需要附上燃尽图。

预期（至少）：
- title：发送项目周报给Alice
- deadline：明天下午3点前
- priority：高
- location：公司
- notes：需要附上燃尽图

### 样例 B（缺地点/优先级）
输入：
- 下周找时间把季度目标初稿整理出来，先写个提纲。

预期：
- title、deadline 可解析
- priority/location 允许为空

### 样例 C（标题+备注）
输入：
- 写周会分享提纲，备注：包含 AI 解析进展和风险。

预期：
- title、notes 可解析
- 其他字段允许为空

## 已知限制 / 已知未完成项
- AI 解析链路已可用，但仍处于第一轮样例扩展期
- priority/location 在输入未明确时常为空（当前可接受）
- 环境变量兜底受启动方式影响：双击 .app 不保证继承 shell 变量
- 本轮重点是 smoke 可用性，不是准确率最终验收
