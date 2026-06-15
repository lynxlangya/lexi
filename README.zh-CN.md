<p align="center">
  <img src="https://img.wangyun.fan/lexi_board.png" alt="Lexi — 中文读者的英文阅读器" width="900">
</p>

# Lexi

[English](README.md) · **简体中文**

一款原生 macOS 英文阅读器，原文身侧实时流式中译；同时带有右侧 AI 朗读器和全局划词翻译浮窗，跟随你进入任何 app。

> **状态 — v2.1.2 MVP release line。** 阅读器、EPUB 导入、流式翻译、AI 朗读、MenuBar 浮窗、生词本、左右双栏布局都已上线。当前技术预览包已使用 Developer ID 签名并通过 Apple 公证，以 DMG 形式通过 R2 和 Homebrew Cask 分发。

---

## 为什么是 Lexi

大多数「AI 翻译」工具把译文当成终点。Lexi 把译文当成脚手架：你真正在读的是英文原文，中文应该待在视野边缘——需要时随手可取，不需要时不抢戏。这一个判断决定了下面所有的设计。

- **克制的排版。** 米色纸张、单列衬线、零拟物。目标是连续阅读 1–2 小时不疲劳。
- **译文按需翻译、本地缓存。** 段落随阅读懒翻译，句句流式呈现，本地落 SQLite——再开同一本书几乎零成本。
- **左右双栏，或上下堆叠。** 可在顶栏一键切换：经典上下堆叠（英文段在上、中文段在下）或新的左右双栏（左 EN 右 ZH，顶对齐）。
- **朗读时不丢阅读上下文。** 右侧展开朗读器，选择原文或译文，当前朗读段高亮，章节结束后自动进入下一章。
- **不止在阅读器里有用。** 在 Safari、Mail、Notes、任何 app 选中英文，调出浮窗即可看到 Lexi 风格的单词卡或整句卡——同一套引擎、同一份生词本。
- **自带 API Key。** 没有账号、没有后端、没有订阅。Key 全部进 Keychain，只发送给你配置的供应商。

---

## 亮点

### 一个为双语阅读而设计的阅读器，而不是「翻译查看器」

- **段落级流式翻译。** 每段一次独立的 LLM 调用，边收边渲染；以上一对 EN/ZH 段作为 few-shot 上下文，保持文学连贯性。
- **两种布局可选。** **左右双栏**（默认）原文与译文等大、顶对齐——短的一侧自然留白；**上下堆叠**是经典「英文为主、中文降权」样式。顶栏或 Settings 一键切。
- **三种显示模式。** 仅原文 / 仅译文 / 双语；阅读时 `⌘B` 直接循环。
- **章节预取。** 你在读第 N 章时，Lexi 在后台静静翻译第 N+1 章。
- **逐段重试。** 单段失败（限流、网络抖动）只有那段显示行内错误，后续段落继续翻译；残缺或截断的译文不会被落库。

### 像播放器一样工作的 AI 朗读

- **右侧抽屉式朗读器。** 阅读器可以切成紧凑播放界面：封面、章节、进度、播放 / 暂停、上一段 / 下一段、上一章 / 下一章，以及可滚动的朗读文本。
- **只朗读原文或译文。** 朗读不是双语混读。你选择原文或已缓存的译文，下方文本也跟随同一种语言。
- **按书生成朗读风格。** 朗读前，Lexi 会用当前翻译引擎抽样书名、章节和正文，生成紧凑的语气、节奏、发音提示。
- **OpenAI 或豆包语音。** OpenAI `gpt-4o-mini-tts` 是成本更友好的默认云端路径，豆包语音继续作为可选供应商保留。供应商 Key 存 Keychain，音频本地缓存。

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
- AI 朗读可选：OpenAI TTS 或豆包语音 API Key + 音色配置

---

## 安装

使用 Homebrew 安装：

```sh
brew tap lynxlangya/tap
brew install --cask lexi
```

也可以直接下载已使用 Developer ID 签名并通过 Apple 公证的 DMG：

[下载 Lexi 2.1.2](https://pub-971ee03b82ad411a9bb26c62a06ca755.r2.dev/lexi/releases/2.1.2/Lexi-2.1.2-installer.dmg)

打开 DMG，把 `Lexi.app` 拖到 `/Applications`，正常打开即可。macOS 仍可能显示标准的首次打开确认，或因为全局划词翻译请求「辅助功能」权限，但当前安装包不应再需要旧的命令行绕过方式。

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
3. 可选：**Settings → 朗读。** 如果要用 AI 朗读，选择 OpenAI TTS（`gpt-4o-mini-tts`）或豆包语音，然后填入对应 Key 和音色配置。
4. **拖一本 EPUB 进书架**（或 `⌘O`）。Lexi 解析文件、抽取封面、入架。
5. 点击书打开阅读器。当前章节立即开始流式翻译。

---

## 配置

| 项 | 位置 | 说明 |
|---|---|---|
| API Key | Settings → 引擎 | macOS Keychain（service `com.lexi.engine.<id>`），不进 SQLite、日志、源码。 |
| 段落布局 | 顶栏按钮 · Settings → 阅读器 → 译文显示 | 上下堆叠 或 左右双栏，默认双栏。 |
| 显示模式 | 顶栏按钮 · `⌘B` | 双语 / 仅原文 / 仅译文。 |
| 字体、行距、主题、强调色 | Settings → 阅读器 | 独立于系统外观，支持跟随系统 / 白天 / 夜间。 |
| 章节预取 | Settings → 阅读器 → 译文显示 | 0–2 章预译。 |
| AI 朗读 | Settings → 朗读 | OpenAI TTS（`gpt-4o-mini-tts`）或豆包语音、独立 API Key、模型 / 音色、语速、本地音频缓存。 |
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
| `Audio/` | OpenAI / 豆包 TTS 接入、朗读风格生成、音频缓存、朗读请求模型 |
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
- **OpenAI / 豆包 TTS + AVFoundation** —— 云端语音合成，`AVPlayer` 本地播放 / 缓存，`AVSpeechSynthesizer` 作为系统朗读兜底

无 iOS / iPadOS target。目标 macOS 26.4，`SDKROOT=macosx`。

---

## 开发

运行单元测试：

```sh
./scripts/test.sh
```

覆盖范围：Data（GRDB 迁移、生词本 / 音频缓存 CRUD）、EPUB 解析、翻译引擎（请求构造、SSE 解析、重试）、阅读器翻译控制器状态机、朗读规划 / 音频缓存、选区上下文解析、段落布局枚举等。

测试脚本会创建临时 DerivedData 并在退出时删除，避免反复命令行验证堆积 `/tmp/lexi-*` 构建产物。仓库里暂无 CI 和 lint 配置。

### 安全

- API Key 必须留在 Keychain，包括翻译引擎 Key 和 TTS 供应商 Key。没有 `.env`、没有 DEBUG-only 覆盖、没有构建期注入路径。
- 一旦 Key 出现在日志、截图、PR、issue 里，立即去对应供应商 dashboard 重置。

---

## 项目状态

v2.1.2 是当前 MVP 技术预览版本线：计划中的 PR 1–10 已合入，后续修复、OpenAI TTS 支持、朗读 UI 迭代和阅读器跨段选择也已落地，并已通过 R2 和 `lynxlangya/tap` 提供 Developer ID 签名且通过 Apple 公证的 DMG 构建包。

路线图和产品决议见 [`DESIGN.md`](DESIGN.md)。

---

## 许可证

暂未授予开源许可证。目前源码可见，但在补充 LICENSE 文件前不代表可以复用或再分发。
