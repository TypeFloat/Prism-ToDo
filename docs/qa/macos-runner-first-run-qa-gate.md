# QA Gate — macOS Runner / 首次可运行验证

## 目标

为 Prism ToDo（macOS-first Phase 1）补一版可执行的 QA Gate，聚焦两个问题：

1. `apps/mobile` 是否已具备 macOS runner
2. 新同学在本机是否能完成第一次可运行验证

当前仓库现状（基于 `/Users/return0/Code/ai-todo` 实际目录抽样）：

- `apps/mobile/lib/` 已有可演示桌面壳
- `apps/mobile/pubspec.yaml` 存在
- `apps/mobile/macos/` 当前未见已生成 runner 目录
- `apps/mobile/test/` 当前未见自动化测试目录

结论：**本 Gate 当前以“阻塞项前置暴露 + 首次运行路径收口”为主，尚不能判定绿灯通过。**

---

## Gate 定义

### Gate 名称
`QA-GATE-P1-MACOS-RUNNER-FIRST-RUN`

### Gate 目的
确保仓库从“只有 Flutter UI 壳”进入“macOS 上首次可生成、可启动、可看到主流程”的状态。

### 通过标准
必须同时满足：

1. **Runner 已生成**
   - `apps/mobile/macos/` 存在
   - Xcode 工程文件存在（如 `Runner.xcodeproj`）
2. **依赖可解析**
   - 在 `apps/mobile` 下可完成 `flutter pub get`
3. **macOS target 可运行**
   - 可执行 `flutter run -d macos`
   - 或至少 `flutter build macos` 成功
4. **首次启动可见主路径**
   - 启动后可见左侧 `Today / Inbox`
   - 可见 `Quick Input`
   - 默认工作区文案与主流程一致：`Quick Input → Inbox → confirm parse → Move to Today → Today`
5. **主流程可手动走通**
   - 输入一条任务后进入 Inbox
   - 可点击 `Confirm parse`
   - 可点击 `Move to Today`
   - Today 中可勾选完成

任一项失败，Gate 不通过。

---

## 当前 QA 判定

### 状态
**Amber / Blocked**

### 原因
1. **macOS runner 缺失**
   - 当前未发现 `apps/mobile/macos/`
   - 说明“macOS-first”口径已写入文档，但 runner 生成尚未落库或尚未在本机执行完成
2. **首次运行证据缺失**
   - 仓库中未看到首跑截图、命令输出记录或测试脚本
3. **自动化回归空白**
   - 当前未见 `test/` 目录，主路径仍依赖人工验证

### QA 结论
在 Dev 完成 runner 生成并给出一次真实运行结果前，本 Gate 应视为 **阻塞**，不能给 Phase 1 “可运行基线成立”的绿灯。

---

## 首次可运行验证清单

建议 Dev/QA 按以下顺序执行并留痕。

### A. 环境前置
在 macOS 本机进入：

```bash
cd /Users/return0/Code/ai-todo/apps/mobile
flutter --version
flutter doctor -v
```

通过条件：
- Flutter CLI 可用
- Xcode / macOS desktop support 正常
- 无阻塞 macOS 构建的红项

### B. 依赖与 runner 生成
```bash
cd /Users/return0/Code/ai-todo/apps/mobile
flutter pub get
flutter create . --platforms=macos
```

通过条件：
- 命令完成，无致命报错
- 生成 `macos/` 目录
- 不破坏现有 `lib/` 主壳入口

### C. 构建 / 运行验证
优先：
```bash
flutter run -d macos
```

备选：
```bash
flutter build macos
```

通过条件：
- App 可启动或 build 成功
- 启动后 UI 不白屏、不崩溃、不出现明显布局断裂

### D. 首次人工冒烟
启动 app 后检查：

1. 左侧显示 `Today` 与 `Inbox`
2. 顶部显示 `Quick Input`
3. Inbox / Today 计数与列表可见
4. 输入 `Buy milk tomorrow` 点击 `Capture to Inbox`
5. 新任务出现在 Inbox 顶部
6. 点击 `Confirm parse` 后按钮置灰/变为 `Confirmed`
7. 点击 `Move to Today` 后任务切到 Today
8. 在 Today 勾选 checkbox 后任务显示完成态

---

## 阻塞项与失败判定

以下任一项应直接拦截：

### P0 阻塞
- `flutter create . --platforms=macos` 失败
- `flutter run -d macos` 无法启动
- 生成 runner 后现有 app 无法编译
- Quick Input 无法创建任务
- `Move to Today` 无效

### P1 高风险
- `Confirm parse` 状态不稳定
- 切换 Today / Inbox 后计数不一致
- 勾选完成后 UI 状态不一致
- macOS 窗口尺寸变化导致布局明显错位

---

## 建议留痕

为避免“本地说能跑，但仓库无证据”，建议至少留以下其中两项：

1. 一次 `flutter doctor -v` 结果摘要
2. 一次 `flutter run -d macos` 成功截图
3. 首跑后 `apps/mobile/macos/` 纳入 git
4. 一条 QA 记录：命令、环境、结果、失败点

---

## QA 建议 Gate 结果

### 本轮建议
- Gate 状态：**Blocked / 待 Dev 补 runner 与首跑证据**
- 优先级：**P0**

### 解锁条件
- Dev 在真实目录补齐 `apps/mobile/macos/`
- 至少完成一次成功启动或成功 build
- QA 根据上方清单复核主流程
