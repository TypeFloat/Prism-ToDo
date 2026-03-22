# Prism ToDo

Prism ToDo is the current macOS-first Flutter delivery for Phase 1.

## Phase 1 target

Phase 1 focuses on a usable macOS desktop shell around:

- 今天
- 收件箱
- 快速记录
- 桌面导航与基础布局

当前不在本轮范围：

- Android / iOS 正式交付
- 账号体系 / 云同步
- calendar / projects / tags / settings-heavy flows
- 过早的深度包拆分

## Current status

当前已验证：

- 依赖可解析
- 静态检查通过
- widget 测试通过
- 本地持久化已接入
- macOS release 构建通过
- dmg 已生成

## Repo structure

```text
ai-todo/
├─ apps/
│  └─ mobile/
│     ├─ lib/
│     ├─ macos/
│     ├─ test/
│     └─ pubspec.yaml
├─ docs/
├─ packages/
└─ README.md
```

## Local development

### 1) Environment check

```bash
flutter --version
flutter doctor -v
```

说明：
- Phase 1 当前只要求 macOS 可运行
- 由于用了 `path_provider`，macOS 构建需要 CocoaPods

### 2) Install dependencies

```bash
cd ~/Code/ai-todo/apps/mobile
flutter pub get
```

### 3) Run the macOS app

```bash
cd ~/Code/ai-todo/apps/mobile
flutter run -d macos
```

### 4) Run tests

```bash
cd ~/Code/ai-todo/apps/mobile
flutter test
```

### 5) Run static analysis

```bash
cd ~/Code/ai-todo/apps/mobile
flutter analyze
```

### 6) Build macOS release

```bash
cd ~/Code/ai-todo/apps/mobile
flutter build macos
```

默认 release app 产物：

```text
apps/mobile/build/macos/Build/Products/Release/Prism ToDo.app
```

## Install and launch

### Option A: run from source

```bash
cd ~/Code/ai-todo/apps/mobile
flutter run -d macos
```

### Option B: install from dmg

当前 dmg 产物：

```text
apps/mobile/dist/Prism-ToDo-macos.dmg
```

安装步骤：
1. 双击打开 dmg
2. 将 `Prism ToDo.app` 拖到 `Applications`
3. 从应用程序目录启动 `Prism ToDo`

### Unsigned / unnotarized warning

当前产物**未签名、未公证**。

因此在其他 macOS 机器上首次打开时，系统可能出现安全提示。若被拦截，可在：

- `系统设置 -> 隐私与安全性`

中手动允许打开，或通过右键 -> 打开 的方式放行。

这属于当前分发形态的已知风险，不代表应用本身损坏。

## Persistence scope

当前本地持久化覆盖：

- 新增任务
- 标记完成 / 取消完成
- 从收件箱移到今天
- 重启后恢复

存储方案：
- 本地 JSON 文件
- 使用 `path_provider` 定位应用支持目录

## Working agreement for Phase 1

在继续加功能前，先判断一件事：

**它是否直接改善 Prism ToDo 的首个 macOS 使用体验？**

如果不是，先延后。
