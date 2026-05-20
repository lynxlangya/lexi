# Lexi · v1 MVP PR 拆分计划

> 给 codex 的工程交接计划。每个 PR 自带验收清单 + 涉及文件 + 设计稿引用 + 与上游 PR 的依赖。
>
> 决策权威：[DESIGN.md](DESIGN.md)。本文件仅做执行编排，所有"为什么"问题去翻 DESIGN.md，**不在本文件复制粘贴**。
>
> **依赖图（关键路径加粗）：**
>
> ```
>   PR1 ─┬─→ PR3 ─┬─→ PR4 ───┐
>        │         ├─→ PR5 ──┤
>   PR2 ─┴─→ PR6 ─┴──────────┼─→ PR7 (Reader 翻译流式) ─→ PR8 (Shelf)
>                              │
>                              └─→ PR9 (MenuBar + NSPanel) ─→ PR10 (Settings + 生词本)
> ```
>
> **PR1/PR2 可并行**；**PR4/PR5/PR6 在 PR3 之后可并行**；**PR8/PR9 在 PR7 之后可并行**；PR10 收尾。

---

## 完成状态（2026-05-20）

本文件现在作为 **v1 MVP 历史拆分计划 + 验收索引** 保留；PR 1-10 已全部合并到 `main`，当前实现事实以源码、[DESIGN.md](DESIGN.md)、[CLAUDE.md](CLAUDE.md) 和 [AGENTS.md](AGENTS.md) 为准。

| 计划 PR | GitHub issue | Merged PR | 状态 |
|---|---:|---:|---|
| PR 1 · Clean slate + 项目骨架 | #1 | #2 | 已合并 |
| PR 2 · Design tokens + 字体 | #3 | #12 | 已合并；字体加载后续由 #13 / #20 修正为 system serif |
| PR 3 · Data layer · GRDB schema + Keychain | #4 | #14 | 已合并 |
| PR 4 · EPUB 解析 | #5 | #15 | 已合并 |
| PR 5 · 翻译引擎层 | #6 | #16 | 已合并 |
| PR 6 · Reader 静态 UI | #7 | #17 | 已合并；Reader toolbar 后续由 #18 / #19 改为原生 macOS toolbar |
| PR 7 · Reader 翻译流式 + 状态机 | #8 | #21 | 已合并 |
| PR 8 · Shelf 视图 + EPUB 导入 | #9 | #22 | 已合并 |
| PR 9 · MenuBar agent + NSPanel | #10 | #23 | 已合并 |
| PR 10 · Settings sheet + 生词本 | #11 | #24 | 已合并 |

完成后的整体验证入口：

```sh
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug -derivedDataPath /tmp/lexi-derived test
xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Release build CODE_SIGNING_ALLOWED=NO
```

---

## PR 1 · Clean slate + 项目骨架

**Goal**：删除 Xcode 模板自带的 Core Data scaffolding，立 v1 目标的源码目录与基础依赖。

**Acceptance**

- [ ] 删除 `lexi/Persistence.swift`、`lexi/lexi.xcdatamodeld/`、`lexi/ContentView.swift`
- [ ] `lexi/lexiApp.swift` 改为最小 `App { Settings { … } MenuBarExtra(…) { … } WindowGroup(…) { … } }`（具体 scene 暂留空，下游 PR 填）
- [ ] 新增源码目录骨架：`lexi/Sources/{App, Reader, MenuBar, Engines, Data, EPUB, UI}/.gitkeep`
- [ ] `lexi.xcodeproj` 文件引用更新（每个目录加入 target）
- [ ] Package.swift 暂不引（v1 通过 Xcode "Add Package Dependency" 加 SPM）—— 但本 PR 加入 README 段落，列出下游 PR 要拉的 SPM：[GRDB.swift](https://github.com/groue/GRDB.swift)、[ZIPFoundation](https://github.com/weichsel/ZIPFoundation)、[SwiftSoup](https://github.com/scinfu/SwiftSoup)、[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- [ ] `xcodebuild -project lexi.xcodeproj -scheme lexi -configuration Debug build` 通过
- [ ] App 启动后窗口空白可显示（暂无内容也行）

**Files**：`lexi/lexiApp.swift`、`lexi.xcodeproj/project.pbxproj`、`lexi/Sources/**`、`CLAUDE.md`（更新"项目处境"段：模板已替换）

**Design ref**：[DESIGN.md §0 决议 4](DESIGN.md)、[CLAUDE.md "Project status"](CLAUDE.md)

**Depends on**：—

**Notes**
- 不在此 PR 改 `lexiApp.swift` 的 scene 逻辑超出"占位"范围 —— scene 内容由 PR6/PR9 填。
- 不引 SwiftLint / SwiftFormat 等附加工具；保持 Xcode 默认。

---

## PR 2 · Design tokens + 字体 → Asset Catalog & SwiftUI

**Goal**：把 [tokens.jsx](design/tokens.jsx) 的颜色 / 字体 / 间距落到 Asset Catalog 与 SwiftUI extension，下游 view 全靠这些 token 拼。

**Acceptance**

- [ ] `lexi/Assets.xcassets` 新建 `Lexi/` 颜色组：`Paper / Raised / Inset / Chrome / Ink / Ink2 / Ink3 / Ink4 / Rule / Rule2 / Accent / AccentSoft / AccentFaint / Selection / Warn / Danger / Shimmer1 / Shimmer2`，每色两套 (Any / Dark)，色值对照 [DESIGN.md §4.1](DESIGN.md#41-颜色暖色双模)
- [ ] `lexi/Sources/UI/LexiColors.swift`：`extension Color` 暴露 `.lexiPaper / .lexiInk / .lexiInk2 …`
- [ ] `lexi/Sources/UI/LexiFonts.swift`：`enum LexiFont { static func serif(_:CGFloat) -> Font; static func sans(_:CGFloat) -> Font; static func zh(_:CGFloat) -> Font; static func mono(_:CGFloat) -> Font }`；New York 用 `Font.custom("NewYork-Regular", size:)`，按 [DESIGN.md §4.2](DESIGN.md#42-字体) 落地
- [ ] `lexi/Sources/UI/LexiSpacing.swift`：`enum LexiSpacing { static let paraGap: CGFloat = 28; static let enZhGap: CGFloat = 6; static let contentMax: CGFloat = 660; static let windowPad: CGFloat = 80 }`、`enum LexiRadius { static let control: CGFloat = 5; static let card: CGFloat = 10; static let window: CGFloat = 10 }`
- [ ] 一个最小 preview view (`TokensPreview.swift`) 把 Palette / Type / Spacing 三张样板平铺，方便人眼对比 [tokens.jsx PalettePanel/TypeSpecimen/SpacingCard](design/tokens.jsx)
- [ ] 暗色模式跟随系统切换（手动改系统 dark mode → 颜色自动反转）

**Files**：`lexi/Assets.xcassets/Lexi/**`、`lexi/Sources/UI/Lexi{Colors,Fonts,Spacing}.swift`、`lexi/Sources/UI/TokensPreview.swift`

**Design ref**：[DESIGN.md §4](DESIGN.md#4-设计基底-tokens) · [tokens.jsx](design/tokens.jsx) · [app.jsx:64 SwiftUI hint](design/app.jsx)

**Depends on**：PR 1（目录骨架）

**Notes**
- **不要用 `.body / .system`**。所有字号 + 行高都手写。规则：lineSpacing = fontSize × (lineHeight - 1)。例：`.font(LexiFont.serif(17)).lineSpacing(17 * 0.72)`。
- 选区色 `.lexiSelection` 是 0.20 alpha 的 accent；用作 `TextSelection.tint(...)`。

---

## PR 3 · Data layer · GRDB schema + Keychain

**Goal**：单一 SQLite 持久层 + Keychain 包装，所有持久化都走这一层。

**Acceptance**

- [ ] 引入 SPM：`groue/GRDB.swift` (>=6.0)
- [ ] `lexi/Sources/Data/Database.swift`：`AppDatabase` actor，`makeShared()` 工厂，路径 `~/Library/Application Support/Lexi/lexi.sqlite`
- [ ] Schema 迁移（v1 initial migration）建表：
  - `books`：id TEXT PK, title TEXT, author TEXT, fileURL TEXT, addedAt INTEGER, lastReadAt INTEGER NULL, progress REAL, coverData BLOB NULL, coverBg TEXT NULL, coverInk TEXT NULL
  - `chapters`：id INTEGER PK, bookId TEXT FK, idx INTEGER, n TEXT, title TEXT, UNIQUE(bookId, idx)
  - `paragraphs`：id INTEGER PK, chapterId INTEGER FK, ord INTEGER, en TEXT, UNIQUE(chapterId, ord)
  - `translations`：id INTEGER PK, paragraphId INTEGER FK, engine TEXT, model TEXT, zh TEXT, createdAt INTEGER, UNIQUE(paragraphId, engine, model)
  - `vocab`：id INTEGER PK, word TEXT, context TEXT NULL, bookId TEXT NULL FK, addedAt INTEGER
  - `progress`：bookId TEXT PK FK, chapterIdx INTEGER, scrollPct REAL, updatedAt INTEGER
  - `engine_config`：engine TEXT PK, model TEXT NOT NULL, lastTestedOK INTEGER, lastTestedAt INTEGER NULL  *(API Key 不进 SQLite，进 Keychain)*
- [ ] Record types：`Book / Chapter / Paragraph / Translation / VocabEntry / ProgressRecord / EngineConfig`，遵循 [DESIGN.md §9](DESIGN.md#9-数据模型初稿) 结构
- [ ] `lexi/Sources/Data/Keychain.swift`：`enum Keychain { static func setApiKey(_ key: String, for engine: EngineID); static func apiKey(for engine: EngineID) -> String?; static func delete(_ engine: EngineID) }`，Service `com.lexi.engine.<id>`
- [ ] 单元测试：建表迁移 idempotent；CRUD smoke test；Keychain 读写

**Files**：`lexi/Sources/Data/{Database,Migrations,Models,Keychain}.swift`、`lexiTests/DataTests.swift`、`Package.swift` 更新

**Design ref**：[DESIGN.md §9](DESIGN.md#9-数据模型初稿)

**Depends on**：PR 1

**Notes**
- GRDB 用 `DatabasePool`（多线程 reader + 单 writer），不要用 `DatabaseQueue`。
- 翻译缓存查询热路径：`SELECT zh FROM translations WHERE paragraphId = ? AND engine = ? AND model = ? LIMIT 1`，加 `(paragraphId, engine)` 索引。
- 不要用 NSPersistentContainer / Core Data —— 决议 4 已禁。

---

## PR 4 · EPUB 解析

**Goal**：从 .epub 文件抽出 metadata + 章节 + 段落 + 封面，落库。

**Acceptance**

- [ ] 引入 SPM：`weichsel/ZIPFoundation`、`scinfu/SwiftSoup`
- [ ] `lexi/Sources/EPUB/EPUBParser.swift`：`func parse(_ url: URL) async throws -> (book: Book, chapters: [(Chapter, [Paragraph])])`
- [ ] 实现流程：
  1. 解压 epub 到临时目录（或内存）
  2. 读 `META-INF/container.xml` 找 OPF 路径
  3. 解析 OPF：`<metadata>`(title/author) + `<manifest>`(items) + `<spine>`(顺序)
  4. 解析 NAV (epub3) / NCX (epub2) 拿章节标题
  5. 每章 XHTML 用 SwiftSoup 取 `<p>` 文本（保留段落边界，去 inline `<span>` 等），组成 `Paragraph.en`
  6. 封面：找 `properties="cover-image"` 或 `<meta name="cover">` 指向的 item；读 bytes 存 `Book.coverData`；找不到则 `coverBg / coverInk` 走排印 fallback（用 [`prototype-shelf.jsx:5 SHELF_BOOKS`](design/prototype-shelf.jsx) 的色板挑一个 hash-pick）
- [ ] 解析完落库：`AppDatabase.importBook(_:)` 单事务写入 books + chapters + paragraphs
- [ ] 失败情形友好抛错：损坏 zip / 缺 OPF / 空 spine 各有具体错误类型
- [ ] 单元测试：放一本公版小书到 `lexiTests/Fixtures/`（推荐 Project Gutenberg Gatsby epub），导入后断言章节数、首尾段文本、有/无 cover

**Files**：`lexi/Sources/EPUB/{EPUBParser, OPFDocument, NavDocument, CoverExtractor}.swift`、`lexiTests/EPUBTests.swift`、`lexiTests/Fixtures/gatsby.epub`

**Design ref**：[DESIGN.md §0 决议 2, 9](DESIGN.md) · [DESIGN.md §5.5 Shelf](DESIGN.md#55-书架视图shelf)

**Depends on**：PR 3

**Notes**
- EPUB 段落保留原排版的"硬段"，不要按句拆分 —— 后续翻译按段送。
- 章节标题用 nav/ncx 的；没有就回退到 XHTML 里第一个 `<h1>/<h2>` 文本；都没有则 "Chapter N"。

---

## PR 5 · 翻译引擎层（3 家 + 探活 + 流式）

**Goal**：统一 `TranslationEngine` protocol，三家实现 + Settings → 引擎里的"测试"探活。

**Acceptance**

- [ ] `lexi/Sources/Engines/TranslationEngine.swift`：
  ```swift
  protocol TranslationEngine {
    var id: EngineID { get }
    func translate(_ paragraphs: [String], model: String) -> AsyncThrowingStream<TranslationChunk, Error>
    func ping(model: String) async throws -> PingResult   // .ok / .keyOkModelUnknown / .fail(reason)
  }
  struct TranslationChunk { let index: Int; let text: String }   // 流式：index = paragraphs 的下标
  ```
- [ ] 三个 impl：
  - `OpenAIEngine`：POST `/v1/chat/completions` with `stream: true`；ping = `GET /v1/models` + grep model 名
  - `AnthropicEngine`：POST `/v1/messages` with `stream: true`；ping = Haiku 1-token request（model 名照用户填的，错也无害）
  - `DeepSeekEngine`：与 OpenAI 同型 wire（兼容 OpenAI API）；endpoint `api.deepseek.com`
- [ ] System prompt（共用，含 zh 风格指引；放 `Engines/Prompts.swift`）—— 译文风格对齐 [chapters.jsx](design/chapters.jsx) 手工译文：信达雅、保留原文标点节奏、不加译者按语
- [ ] `EngineRegistry`：根据 `EngineConfig + Keychain` 实例化引擎；切换默认引擎不重译已缓存段（[DESIGN.md §0 决议 8](DESIGN.md)）
- [ ] HTTP client 用 `URLSession` + `AsyncBytes`/SSE 手解（不引第三方）
- [ ] 单元测试：mock URLSession，断言 ping 三种状态映射 + 流式 chunk 顺序

**Files**：`lexi/Sources/Engines/{TranslationEngine, OpenAIEngine, AnthropicEngine, DeepSeekEngine, EngineRegistry, Prompts, SSEParser}.swift`、`lexiTests/EngineTests.swift`

**Design ref**：[DESIGN.md §8 引擎模型](DESIGN.md#8-翻译引擎模型) · [DESIGN.md §0 决议 7, 8, 14](DESIGN.md) · [DESIGN.md §0 末尾 Engine 配置 UI 细节](DESIGN.md)

**Depends on**：PR 3（EngineConfig + Keychain）

**Notes**
- SSE 解析自己写：按 `data: …\n\n` 分块，特殊处理 `[DONE]`、OpenAI 的 `delta.content` 与 Anthropic 的 `content_block_delta`。
- 翻译失败按段抛 `EngineError.paragraphFailed(index:reason:)`，上层落到段错误态 UI（[DESIGN.md §5.3](DESIGN.md#53-翻译状态机per-chapter--per-paragraph)）。
- **DEBUG 模式 secrets 加载**：本 PR 需要在 `Sources/Engines/` 下加一个 `DevSecrets.swift`（or 类似），仅在 `#if DEBUG` 编译路径里读取仓库根目录的 `.env.local`（详见 [CLAUDE.md "Local secrets" 段](CLAUDE.md)），把 `OPENAI_API_KEY` / `OPENAI_MODEL` / `ANTHROPIC_API_KEY` / `ANTHROPIC_MODEL` / `DEEPSEEK_API_KEY` / `DEEPSEEK_MODEL` 注入到默认 `EngineRegistry`，方便开发期跑通真实 ping。RELEASE 构建路径里这个 loader **必须被 `#if !DEBUG` 完全排除**（不要走 `if`/runtime check 这种容易漏的方式），keys 一律走 Keychain。空 key → 跳过该引擎，不抛错。
- `.env.local` 已经在仓库（gitignored），格式见 [`.env.example`](.env.example)。本 PR **不要** commit 任何带真实 key 的文件。

---

## PR 6 · Reader 静态 UI（无翻译，hardcode 数据）

**Goal**：搭出 Reader 主窗口骨架 + 侧栏 TOC + 阅读列；用 `chapters.jsx` 的 Gatsby 数据 hardcode，下一波 PR 接真实数据。

**Acceptance**

- [ ] `lexi/Sources/Reader/ReaderWindow.swift`：`Scene` 注册一个标题 "Lexi" 的 `WindowGroup`；窗口默认 1200×760，`.titled, .fullSizeContentView, .titlebarAppearsTransparent`
- [ ] `NavigationSplitView`：sidebar = `TOCSidebar`(232pt)；detail = `ReadingColumn`(max-width 660pt 居中)
- [ ] `TOCSidebar`：渲染章节列表，每章罗马数字 + 标题 + 右侧状态 dot 占位（dot 都灰，等 PR7 接翻译状态）
- [ ] `ReadingColumn`：上下 padding 56/96，每段 = `Text(en).font(.serif 17).lineSpacing(17*0.72)` + 6pt + `Text(zh).font(.zh 13.5).lineSpacing(13.5*0.78).foregroundColor(.lexiInk2)` + 28pt
- [ ] 顶部 toolbar 自绘到 contentView 顶（fullSizeContentView 下手控）：traffic lights 默认 + 中部 "Book · Chapter N · n/m" + 右侧 IconBtn 组（侧栏 / A- / A+ / 译文模式 / 引擎 / 主题 / 更多），按 [DESIGN.md §5.1](DESIGN.md#51-窗口骨架) 布局；点击逻辑下个 PR 接，本 PR 仅显示
- [ ] 底栏 28pt 高，hairline border：左空 / 右 "{n}% · 全书 {m}%" 占位
- [ ] 1pt 进度 hairline 在底栏正上方
- [ ] 字号 `@AppStorage("reader.fontSize")` (default 17)；A-/A+ 可点改变 hardcoded 段落字号
- [ ] hardcode data：把 [`chapters.jsx`](design/chapters.jsx) 的 CHAPTERS 翻成 Swift `let demoChapters: [(n: String, title: String, paras: [(en: String, zh: String)])]`，放 `Sources/Reader/DemoData.swift`
- [ ] 截图对照 [reader.jsx ReaderWindow direction='quiet'](design/reader.jsx) light/dark 各一张，PR 描述里贴

**Files**：`lexi/Sources/Reader/{ReaderWindow, TOCSidebar, ReadingColumn, ChapterHeader, ParaView, ReaderToolbar, ReaderStatusBar, DemoData}.swift`

**Design ref**：[DESIGN.md §5.1, §5.2](DESIGN.md#51-窗口骨架) · [reader.jsx](design/reader.jsx) · [prototype-parts.jsx](design/prototype-parts.jsx) · [app.jsx:97 SwiftUI Quiet hint](design/app.jsx)

**Depends on**：PR 2

**Notes**
- 不接键盘快捷键（PR9 一起做）。
- traffic lights 用系统的 `standardWindowButton`，不要自绘。
- 侧栏 "◁ 书架" 按钮位先放，点击 noop（PR8 接）。

---

## PR 7 · Reader 翻译流式 + 状态机

**Goal**：进入未缓存章 → 流式 per-paragraph 翻译；shimmer/cached/error 三态完整。

**Acceptance**

- [ ] `lexi/Sources/Reader/ChapterTranslationController.swift`：
  - 输入 chapterId；查 DB 已缓存段数；未缓存段调 `EngineRegistry.current.translate(...)`
  - 维护 `@Observable` state：`(idle | translating(done: Int) | cached | error)`
  - 每收一个 chunk → 落库 + 更新 state；切章先 cancel 上一个 stream
  - 预取下一章（按设置 `reader.prefetch` 默认 1，0/1/2 三档）
- [ ] `ParaView` 接 controller state：`idx < done` 渲染 ZH；`idx >= done` 渲染 shimmer 占位（两条 92% / 64% 宽，1.6s linear infinite，gradient `LinearGradient([.lexiShimmer1, .lexiShimmer2, .lexiShimmer1])`，phase 用 `TimelineView` 推动）；段错误态 = warn icon + "本段翻译失败" + 重试本段按钮
- [ ] `TOCSidebar` 状态 dot 接通：translating = spinner（旋转 1.2s）、cached = ink3 灰、idle = ink4 小 dot
- [ ] 底栏左侧绑定 controller："正在翻译 · {engine} · {done}/{total}" 带 spinner / 否则 "本章已缓存 · {engine}"
- [ ] ⌘B 切换 transMode (both/en/zh)；⌘[/] 切章；⌘+/- 字号；⌘0 侧栏；以上键位走 `KeyboardShortcuts` SPM
- [ ] 接入 hardcode → 真实数据：替换 `DemoData.swift`，从 DB 读章节（PR8 之前可先用 fixture import）

**Files**：`lexi/Sources/Reader/{ChapterTranslationController, ParaView, Shimmer, ReaderShortcuts}.swift`、改 `TOCSidebar.swift` / `ReadingColumn.swift` / `ReaderStatusBar.swift`

**Design ref**：[DESIGN.md §5.3](DESIGN.md#53-翻译状态机per-chapter--per-paragraph) · [prototype.jsx:54 translation effect](design/prototype.jsx) · [prototype-parts.jsx PPara](design/prototype-parts.jsx)

**Depends on**：PR 3, PR 4, PR 5, PR 6

**Notes**
- 切章必须 cancel 当前 Stream（`Task.cancel()`）—— 否则切回原章会有重复落库竞争。
- shimmer 用 `Canvas { ctx, size in ... }` 或 `LinearGradient` + `.mask`；不要用 SwiftUI `.redacted(.placeholder)`，那个外观太 iOS。
- 预取写在 `ChapterTranslationController` 的 `onAppear` 副作用里，跟主翻译共享同一个 stream pool（用 actor 序列化避免 race）。

---

## PR 8 · Shelf 视图 + EPUB 导入 + 右键菜单

**Goal**：书架视图 + 拖拽 EPUB → 解析入库 → 打开。

**Acceptance**

- [ ] `lexi/Sources/Reader/ShelfView.swift`：`LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 28)], spacing: 36)`
- [ ] `BookCard`：cover (144×216, `cornerRadius(2)`, `shadow(color: .black.opacity(0.18), radius: 14, y: 6)`) + title + author + 1pt 进度 hairline + MONO 状态行；hover lift `translateY(-3pt)` 用 `.scaleEffect` 或 `.offset` 动画 180ms
- [ ] 工具栏：`.searchable(text: $query, placement: .toolbar)` (⌘F) + 排序 segmented (最近/书名/进度) + "+ 添加 EPUB" 按钮（铜色 soft）
- [ ] 拖拽接收 `.onDrop(of: [.epub], delegate: ShelfDropDelegate)`：dragOver 全屏 overlay "松开以加入书架"；松手 → 调 `EPUBParser` → 落库 → toast "已加入书架 · {title}"
- [ ] 分区："继续阅读"（首 3 条按 lastReadAt 倒序）+ "书架"（其余按选定排序）
- [ ] 右键菜单：打开 ⌘O · 继续阅读 ↵ · Finder 中显示 ⌥⌘R · 清除翻译缓存 · 从书架移除（danger）—— 用 `.contextMenu`
- [ ] sidebar "◁ 书架" 按钮接通：切到 ShelfView；ShelfTitleBar 取代 reader title bar（"书架" 标题 + N 本书 + 返回阅读）
- [ ] 启动行为：按 [DESIGN.md §5.6 通用 tab "启动时"](DESIGN.md) 三选项；default `last`（无 last 则 shelf）
- [ ] 空状态：[DESIGN.md §5.5 + prototype-shelf 200 行](design/prototype-shelf.jsx) 的搜索无结果文案

**Files**：`lexi/Sources/Reader/{ShelfView, BookCard, BookCover, ShelfTitleBar, ShelfDropDelegate, ShelfContextMenu, Toast}.swift`

**Design ref**：[DESIGN.md §5.5](DESIGN.md#55-书架视图shelf) · [prototype-shelf.jsx](design/prototype-shelf.jsx) · [app.jsx:263 SwiftUI 书架 hint](design/app.jsx)

**Depends on**：PR 4, PR 6

**Notes**
- 封面优先用 `Book.coverData` 渲染原图；没有则走 `coverBg + coverInk` 排印 fallback (按 [DESIGN.md §0 决议 9](DESIGN.md))。
- "清除翻译缓存" 对话 `MB` 数：`SELECT SUM(LENGTH(zh)) FROM translations JOIN paragraphs ...` 估算（粗 byte 数 / 1024 / 1024）。

---

## PR 9 · MenuBar agent + NSPanel 浮窗 + 全局 ⌘⇧L

**Goal**：常驻状态栏 + 全局划词翻译浮窗（B Power 方向）。

**Acceptance**

- [ ] 在 `Info.plist` 加 `LSUIElement = false`（要保留 dock 图标）；但允许"关闭主窗口默认不退出"—— 通过 `NSApplication.shared.setActivationPolicy(.accessory)` 在主窗口全关后切到 accessory 模式（按 [DESIGN.md §5.6 通用 tab 决议](DESIGN.md)，默认 "保留在 menu bar"）
- [ ] `MenuBarExtra("Lexi", systemImage: …)`：自定义 view 用 [`LexiGlyph` SVG](design/menubar-stage.jsx) 复刻为 SwiftUI `Shape`；激活态 (有 popup 显示) 背景 `.lexiAccentSoft`
- [ ] 点击 → 280pt 下拉 panel（[design/menubar-app.jsx:419 LexiMenu](design/menubar-app.jsx)）：header + 统计区 (生词本 N 词 / 今日查询 N) + 菜单项 (划词翻译⌘⇧L / 即时翻译⌘⇧T / 打开阅读器⌘⇧K / 生词本 / 今日复习(灰显，v1 不接) / 设置⌘, / 退出⌘Q)。**注意**：原型 `menubar-app.jsx:458` 写的是 ⌘⇧R，与 Reader 内"重新翻译本章"冲突；按 DESIGN.md §6.1 末尾决议改用 ⌘⇧K（=同"显示/隐藏 Reader"键，本就是同一动作）
- [ ] `NSPanel` 浮窗：`[.nonactivatingPanel, .borderless, .fullSizeContentView]`，`isFloatingPanel = true`，`level = .floating`，`becomesKeyOnlyIfNeeded = true`；容器 `NSVisualEffectView(.hudWindow, .behindWindow)`
- [ ] 浮窗内容用 SwiftUI 渲染 (`NSHostingView`)：四态 `loading / word / sentence / error`，按 [menubar-popup-v2.jsx](design/menubar-popup-v2.jsx) **B Power 方向**实现：
  - Word：UK + US 双 IPA + 全部义项 + 例句 inset + 相关词（斜体 dotted underline）+ 引擎 pill `GPT / Claude / DeepSeek` + 生词本按钮
  - Sentence：原句斜体 + hairline + 译文 + 引擎 pill（**无备选 inset、无发送按钮**，[DESIGN.md §0 决议 10/11](DESIGN.md)）
  - Pin 按钮（pinned 时忽略 click-outside）+ Close (Esc)
- [ ] 选区检测：`NSEvent.addGlobalMonitor(matching: .leftMouseUp)` + AX API 读选中文本；单词正则 `^[a-zA-Z'\u{2019}-]+$` 决定 word 还是 sentence；trigger 方式 PopClip-chip vs instant 由设置控（v1 默认 chip）
- [ ] ⌘⇧L 全局快捷键：[`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) SPM 注册 `KeyboardShortcuts.Name(.translateSelection)`；按下 → 取当前选区 → 弹浮窗（不需 chip 中转）
- [ ] ⌘⇧T 即时翻译：取选区 → 调引擎 → 用 AX API 替换选区文本（注意：浏览器选区可能只读，失败 fallback 写剪贴板 + toast "已复制译文"）
- [ ] ⌘⇧K 显示/隐藏 Reader 主窗口
- [ ] 浮窗点外部消失（除非 pinned）：`NSEvent.addGlobalMonitor(matching: .leftMouseDown)`
- [ ] 朗读：speaker icon 接 `AVSpeechSynthesizer`（[DESIGN.md §0 决议 12](DESIGN.md)）

**Files**：`lexi/Sources/MenuBar/{LexiMenuBarExtra, LexiGlyph, LexiMenuPanel, PopupPanel, PopupContent, WordCard, SentenceCard, LoadingCard, ErrorCard, EnginePill, SelectionMonitor, GlobalShortcuts, TextReplacement, Speech}.swift`、`Info.plist`

**Design ref**：[DESIGN.md §6](DESIGN.md#6-menubar-浮窗) · [menubar-app.jsx](design/menubar-app.jsx) · [menubar-popup-v2.jsx](design/menubar-popup-v2.jsx) · [menubar-stage.jsx](design/menubar-stage.jsx) · [app.jsx:205 SwiftUI 浮窗 hint](design/app.jsx)

**Depends on**：PR 2, PR 5

**Notes**
- AX API 读选中文本要 `kAXSelectedTextAttribute`；需要在 `Info.plist` 加 `NSAccessibilityUsageDescription`，首次唤起浮窗前主动引导用户开"辅助功能"权限（系统设置 → 隐私与安全 → 辅助功能 → Lexi）。
- 浮窗 `NSPanel` 不要让它进 spaces 切换；`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`。
- 选区检测 *NOT* 主动 polling，只在 mouseup global monitor 内 query 一次。
- ⌘⇧T 替换选区：先尝试 AX `kAXSelectedTextAttribute = newValue`；不行 fallback 模拟 `cmd+c → 翻译 → cmd+v` （后者改剪贴板，要可关）；最终极端 fallback "复制到剪贴板 + toast"。

---

## PR 10 · Settings sheet + 生词本

**Goal**：4 tab 设置面板 + 生词本 list；引擎配置接到 PR5。

**Acceptance**

- [ ] `lexi/Sources/UI/SettingsSheet.swift`：modal 720×580，`NavigationSplitView`（**不要** `Scene(.settings) + TabView`，[DESIGN.md §10.6](DESIGN.md#106-settings)）
- [ ] 4 tab：通用 / 引擎 / 快捷键 / 阅读器
  - **通用**：启动行为 select / 关闭主窗口行为 select / 缓存路径显示 / 自动检查更新 toggle / 匿名崩溃日志 toggle（**iCloud 同步 toggle 不渲染，决议 4**）
  - **引擎**：默认引擎 (段落 + 划词) select、3 行 API Keys（OpenAI / Anthropic / DeepSeek，每行 SecureField + Model TextField + 测试按钮 + 状态点；详见 [DESIGN.md §0 末尾 Engine 配置 UI 细节](DESIGN.md)）、翻译缓存 (进度条 + 按书清除 / 全部清除)。**不渲染 "自定义引擎" section（决议 7）**
  - **快捷键**：6 阅读 + 3 导航 + 冲突检测 toggle；用 `KeyboardShortcuts.Recorder` 录入
  - **阅读器**：字号 slider 14-22 / 衬线字体 select / 行距 segmented (紧凑/标准/宽松) / 默认译文模式 segmented / 主题 segmented / 重音色 swatch picker。**"译文视觉强度" A/B/C 不渲染（决议 1）；"章节预取" 0/1/2 渲染**
- [ ] "测试" 按钮调 `engine.ping(model:)`，结果落 `EngineConfig.lastTestedOK` + toast；状态点颜色按 [DESIGN.md §0 末尾](DESIGN.md)：绿 ok / 黄 keyOkModelUnknown / 红 fail / 灰 unset
- [ ] 所有 toggle / select 用 `@AppStorage`（key 命名 `reader.fontSize` / `engine.default.chapter` / `general.onClose` 等）
- [ ] `lexi/Sources/Reader/VocabView.swift`：简单 list，行 = word + IPA + 添加时间 + 来源书；toolbar = 搜索 + 删除选中；菜单栏 "生词本…" 点击进
- [ ] Reader "+ 生词本" 按钮接通：写入 `vocab` 表
- [ ] menu-bar 下拉 "生词本 (N 词)" 数字接 DB 实时

**Files**：`lexi/Sources/UI/{SettingsSheet, SettingsTabs, EngineRow, APIKeyField, ModelField, ShortcutRecorder}.swift`、`lexi/Sources/Reader/VocabView.swift`、各处 `@AppStorage` 接通

**Design ref**：[DESIGN.md §5.6](DESIGN.md#56-设置面板settings-sheet) · [prototype-settings.jsx](design/prototype-settings.jsx) · [DESIGN.md §0 末尾](DESIGN.md) · [app.jsx:315 SwiftUI 设置 hint](design/app.jsx)

**Depends on**：PR 3, PR 5, PR 6, PR 9

**Notes**
- Sheet 自己的"红绿灯"是装饰：点红灯 = 关闭 sheet，**不是关闭真窗口**（[DESIGN.md §5.6](DESIGN.md#56-设置面板settings-sheet)）。
- 缓存进度条用 `Capsule().frame(width:)`，**不用** `ProgressView`。
- 引擎切换是即时生效（不等下次启动）—— 通过 `@Published EngineRegistry.shared.current` 通知 Reader。

---

## 出 PR 顺序建议

| 周次 | 主线 PR | 可并行 | 期望状态 |
|---|---|---|---|
| W1 | PR1 → PR3 | PR2 | 项目能跑，DB schema 就绪 |
| W2 | PR4 + PR5 + PR6 同时启动 |  | 三条主线并行，可单独 review |
| W3 | PR7 | 准备 PR8/9 | Reader 翻译流式跑通，端到端可读一章 |
| W4 | PR8 + PR9 |  | 书架 + 全局浮窗，**MVP 主体可用** |
| W5 | PR10 | 收尾 / bug bash | Settings + 生词本，对外 alpha |

我的角色：PR1/PR3/PR5/PR7/PR9 五个高风险节点跑 `/review`，余下 codex 独立推进，我做架构二审。

---

## 跨 PR 约定

- **不引** SwiftUI 之外的 UI 框架（不引 The Composable Architecture、不引 Pointfree 整套 stack）；Observation 走 `@Observable` / `@AppStorage`
- 测试：DB / Engine / EPUB 三层有单测；UI 不强求；端到端用 manual smoke test
- 文档：每个 PR 描述里贴对应 design jsx 的 1-2 张 prototype 截图 + 实现截图对照
- 提交：每个 PR 单一职责；同一 PR 内不混 refactor 与新功能；commit message 写 "why" 不写 "what"
