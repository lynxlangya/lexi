<p align="center">
  <img src="https://img.wangyun.fan/lexi.png" alt="Lexi — 中文读者的英文阅读器" width="900">
</p>

# Lexi

[English](README.md) · **简体中文**

一款原生 macOS 英文阅读器，原文身侧实时流式中译；同时附带一个全局划词翻译浮窗，跟随你进入任何 app。

> **状态 — v2.0.0 MVP release。** 阅读器、EPUB 导入、流式翻译、MenuBar 浮窗、生词本、左右双栏布局都已上线。当前技术预览包通过 GitHub Releases 和 Homebrew Cask 分发。

---

## 为什么是 Lexi

大多数「AI 翻译」工具把译文当成终点。Lexi 把译文当成脚手架：你真正在读的是英文原文，中文应该待在视野边缘——需要时随手可取，不需要时不抢戏。这一个判断决定了下面所有的设计。

- **克制的排版。** 米色纸张、单列衬线、零拟物。目标是连续阅读 1–2 小时不疲劳。
- **译文按需翻译、本地缓存。** 段落随阅读懒翻译，句句流式呈现，本地落 SQLite——再开同一本书几乎零成本。
- **左右双栏，或上下堆叠。** 可在顶栏一键切换：经典上下堆叠（英文段在上、中文段在下）或新的左右双栏（左 EN 右 ZH，顶对齐）。
- **不止在阅读器里有用。** 在 Safari、Mail、Notes、任何 app 选中英文，调出浮窗即可看到 Lexi 风格的单词卡或整句卡——同一套引擎、同一份生词本。
- **自带 API Key。** 没有账号、没有后端、没有订阅。Key 全部进 Keychain，不出本机。

---

## 亮点

### 一个为双语阅读而设计的阅读器，而不是「翻译查看器」

- **段落级流式翻译。** 每段一次独立的 LLM 调用，边收边渲染；以上一对 EN/ZH 段作为 few-shot 上下文，保持文学连贯性。
- **两种布局可选。** **左右双栏**（默认）原文与译文等大、顶对齐——短的一侧自然留白；**上下堆叠**是经典「英文为主、中文降权」样式。顶栏或 Settings 一键切。
- **三种显示模式。** 仅原文 / 仅译文 / 双语；阅读时 `⌘B` 直接循环。
- **章节预取。** 你在读第 N 章时，Lexi 在后台静静翻译第 N+1 章。
- **逐段重试。** 单段失败（限流、网络抖动）只有那段显示行内错误，整章阅读不被打断。

### 一个跟随你到全局的 MenuBar 浮窗

- **全局划词翻译。** 在任何 macOS app 选中英文，按 `⌘⇧L`，浮窗在选区附近弹出，给出 Lexi 风格的单词卡或整句卡。
- **单词 / 短语 / 整句自动分流。** 浮窗按选区形状选用合适的卡片：单词出多义项 + 音标的词典卡，短语出 idiom 解释，整句出干净的整段译文。
- **一键入生词本。** 浮窗里点收藏，词条进入生词本；若是在阅读器里收藏的，会同时关联到对应的书。

### 记得上下文的生词本

- **快照式释义。** 收藏一个词时，Lexi 不只是存词头，还把当下 LLM 返回的完整 lookup 结果（多义项、音标、例句）一并落库——之后哪怕供应商改了模型，你存的那次结果不会被悄悄改写。
- **按书 / 全局两个 scope。** 阅读时收的词记得来自哪本书，浮窗收的词进入全局池。生词本可按任一维度过滤。
- **本地优先。** 所有词条进 SQLite，无同步无埋点。

### 引擎灵活但不泛滥

- **三个预设：** OpenAI、Anthropic、DeepSeek。每个支持自由填写 model 名（今天 `gpt-4-turbo`，明天 `gpt-5`，不用等 app 升级）。
- **段落引擎和浮窗引擎可分别配置。** 章节翻译用便宜快速的模型，划词解释用更聪明的——反过来也行。
- **章节中途切换引擎是无损操作。** 已缓存段保留原引擎的译文，只对后续未翻段生效。

---

## 运行环境

- **macOS 26.4 及以上**
- **Xcode 26 及以上**（Swift 5.0）
- 至少一个 LLM 引擎的 API Key：OpenAI / Anthropic / DeepSeek 任选其一

---

## 安装

使用 Homebrew 安装：

```sh
brew tap lynxlangya/tap
brew install --cask --no-quarantine lexi
```

也可以从 [GitHub Releases](https://github.com/lynxlangya/lexi/releases) 下载最新 zip。

当前预览包是 ad-hoc 签名，尚未经过 Apple notarization。若 macOS 首次启动时拦截，可在「系统设置 → 隐私与安全性」中允许打开 Lexi，或执行：

```sh
xattr -dr com.apple.quarantine /Applications/Lexi.app
open /Applications/Lexi.app
```

## 从源码运行

```sh
git clone https://github.com/lynxlangya/lexi.git
cd lexi
open lexi.xcodeproj
```

Xcode 里 ⌘R 构建运行。或命令行：

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug build
```

首次配置：

1. 启动 app，书架是空的。
2. **Settings → 引擎。** 粘贴 OpenAI / Anthropic / DeepSeek 任一个的 API Key，填上 model 名（有默认建议），点 **测试** 验证。
3. **拖一本 EPUB 进书架**（或 `⌘O`）。Lexi 解析文件、抽取封面、入架。
4. 点击书打开阅读器。当前章节立即开始流式翻译。

---

## 配置

| 项 | 位置 | 说明 |
|---|---|---|
| API Key | Settings → 引擎 | macOS Keychain（service `com.lexi.engine.<id>`），不进 SQLite、日志、源码。 |
| 段落布局 | 顶栏按钮 · Settings → 阅读器 → 译文显示 | 上下堆叠 或 左右双栏，默认双栏。 |
| 显示模式 | 顶栏按钮 · `⌘B` | 双语 / 仅原文 / 仅译文。 |
| 字体、行距、主题、强调色 | Settings → 阅读器 | 独立于系统外观，支持跟随系统 / 白天 / 夜间。 |
| 章节预取 | Settings → 阅读器 → 译文显示 | 0–2 章预译。 |
| 快捷键 | Settings → 快捷键 | 大多数可改键，冲突检测可选。 |

### 常用快捷键

- `⌘⇧L` —— 全局划词翻译浮窗（任何 app 都生效）
- `⌘⇧K` —— 任意位置显示 / 隐藏阅读器
- `⌘B` —— 在阅读器里循环切换显示模式（双语 / 仅原文 / 仅译文）
- `⌘+` / `⌘-` —— 阅读中调整字号

---

## 架构

Lexi 是一个 Xcode 项目（`lexi.xcodeproj`），**不是** Swift Package，依赖通过 Xcode 项目管理。源码组织在 `lexi/Sources/` 下：

| 模块 | 职责 |
|---|---|
| `App/` | `@main` 入口、MenuBarExtra 接线、生命周期、scene |
| `Reader/` | 阅读器主窗、书架、EPUB 导入、段落渲染、翻译状态 UI、生词本 sheet |
| `MenuBar/` | 状态栏 agent、选区监听（Accessibility API）、`NSPanel` 浮窗、朗读、全局快捷键 |
| `Engines/` | OpenAI / Anthropic / DeepSeek 接入、SSE 解析、结构化 lookup schema、prompt |
| `Data/` | GRDB `AppDatabase` actor、迁移、模型、Keychain 包装 |
| `EPUB/` | 归档解压、OPF/Nav 解析、封面抽取 |
| `UI/` | 设计 token、字体、Settings sheet、可复用控件 |

v1 产品决议见 [`DESIGN.md`](DESIGN.md)，MVP 的历史 PR 拆解见 [`PR-PLAN.md`](PR-PLAN.md)。

---

## 技术栈

- **Swift 5 / SwiftUI**，与 AppKit 混编（`NSPanel`、`NSEvent` 监听、自绘窗口 chrome）
- **[GRDB.swift](https://github.com/groue/GRDB.swift)** —— actor `DatabasePool` 包装的 SQLite
- **[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)** —— EPUB 解压
- **[SwiftSoup](https://github.com/scinfu/SwiftSoup)** —— XHTML 章节解析
- **[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)** —— 可改键的全局快捷键
- **macOS Keychain** —— API Key 存储
- **`AVSpeechSynthesizer`** —— 系统 TTS，零依赖

无 iOS / iPadOS target。目标 macOS 26.4，`SDKROOT=macosx`。

---

## 开发

运行单元测试：

```sh
./scripts/test.sh
```

覆盖范围：Data（GRDB 迁移、生词本 CRUD）、EPUB 解析、翻译引擎（请求构造、SSE 解析、重试）、阅读器翻译控制器状态机、选区上下文解析、新的段落布局枚举等。

测试脚本会创建临时 DerivedData 并在退出时删除，避免反复命令行验证堆积 `/tmp/lexi-*` 构建产物。仓库里暂无 CI 和 lint 配置。

### 安全

- API Key 必须留在 Keychain。没有 `.env`、没有 DEBUG-only 覆盖、没有构建期注入路径。
- 一旦 Key 出现在日志、截图、PR、issue 里，立即去对应供应商 dashboard 重置。

---

## 项目状态

v2.0.0 是第一个 MVP 技术预览版本：计划中的 PR 1–10 已合入，后续修复也已落地，并已通过 GitHub Releases 和 `lynxlangya/tap` 提供可安装构建包。

路线图和产品决议见 [`DESIGN.md`](DESIGN.md)。

---

## 许可证

暂未授予开源许可证。目前源码可见，但在补充 LICENSE 文件前不代表可以复用或再分发。
