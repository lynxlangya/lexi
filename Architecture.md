<!--
Architecture.md
Lexi – macOS 14+ SwiftUI app
-->

# Lexi Architecture

## 1. 项目概述 (Project Overview)

Lexi 是一款极简的 macOS “划词翻译浮窗”应用。用户在任意 App 中选中文本后，按下全局快捷键即可在鼠标附近唤起毛玻璃浮窗，并得到实时翻译结果。  
核心价值：

- **零打扰**：无标题栏、悬浮毛玻璃窗口，靠近鼠标出现，点击外部自动消失。
- **全局可用**：通过 Accessibility API 读取当前应用选中文本，不依赖特定编辑器。
- **多引擎支持**：同时兼容 OpenAI/DeepSeek 等流式 LLM，以及 Google 免费翻译兜底（历史上的 Microsoft 引擎已下线，仅保留 id→google 的迁移逻辑）。
- **可扩展**：通过引擎描述模型 + 服务层策略分发，方便后续接入更多模型或插件能力。

**技术栈**

- **Language**: Swift 5.x
- **UI Frameworks**: SwiftUI（App 生命周期、界面）、AppKit（NSWindow 定制、事件监控）
- **System APIs**:
  - Accessibility / AXUIElement（选中文本获取）
  - Carbon HIToolbox（全局快捷键）
  - CoreGraphics CGEvent（Cmd+C 兜底拷贝选区）
- **Networking**: Foundation `URLSession` + Swift Concurrency
- **Key Libraries**: 无第三方依赖（当前全部使用系统框架）

---

## 2. 架构设计 (Architecture Design)

### 2.1 设计模式：MVVM

Lexi 采用 MVVM（Model–View–ViewModel）结构：

- **View（SwiftUI）**

  - 负责渲染 UI、接收用户输入、展示状态。
  - 不直接发起网络请求或访问系统服务。
  - 代表文件：`Lexi/ContentView.swift`、`Lexi/Popup/TranslationPopupView.swift`、`Lexi/Popup/SettingsView.swift`

- **ViewModel**

  - 维护翻译过程的状态（源文本、翻译结果、流式 token、错误信息、加载状态）。
  - 提供 `translate` / `streamTranslate` 等动作，协调服务层输出到 UI。
  - 代表文件：`Lexi/Popup/TranslationViewModel.swift`

- **Model / Service / Core 抽象**

  代码按职责分到 `Lexi/Core/` 下三个子目录 + `Lexi/Popup/` 浮窗 feature：

  - **Core/Engine**：引擎/模型/语言配置 + Keychain  
    `EngineStore.swift`、`TranslationEngine.swift`、`ModelOptions.swift`、`LanguageOptions.swift`、`APIKeyStore.swift`
  - **Core/Translation**：翻译服务 + 抽象  
    `TranslationService.swift`（actor，策略分发入口）、`LLMService.swift`、`FreeTranslateService.swift`、`TranslationPromptStrategy.swift`、`TranslationCache.swift`、`LanguageDetector.swift`
  - **Core/System**：系统能力（选区、窗口、快捷键、TTS、开机自启）  
    `SelectionManager.swift`、`HotKeyManager.swift`、`WindowManager.swift`、`TextToSpeechService.swift`、`LaunchAtLoginManager.swift`、`HotKey.swift`
  - **Popup**：浮窗 UI + 单词卡专用 ViewModel  
    `TranslationPopupView.swift`、`WordExplanationView.swift`、`SettingsView.swift`、`ErrorBannerView.swift`、`HotKeyRecorderField.swift`、`TranslationViewModel.swift`、`WordExplanation.swift`
  - **Reader**：占位目录，后续 EPUB 阅读器代码进入这里
  - **Shared/Utilities**：跨层小工具 `KeychainHelper.swift`、`Notifications.swift`、`AppKitHelpers.swift`、`WindowAccessor.swift`

  `Core/` 是可复用引擎，`Popup/` 和未来 `Reader/` 都是其消费者。若 `Reader/` 体量起来或出 iOS 版，`Core/` 是天然的 SPM 切分点，但目前没必要前置抽。

### 2.2 数据流向图（文字描述）

从“用户按下快捷键”到“显示翻译结果”的数据流如下：

1. **用户触发**  
   用户在任意 App 中选中文本，按下 Lexi 全局快捷键。

2. **全局热键捕获**  
   `HotKeyManager` 通过 Carbon `RegisterEventHotKey` 捕获热键，回调中向 `NotificationCenter` 发送 `.lexiHotKeyPressed`。

3. **入口 View 处理**  
   `ContentView` 监听 `.lexiHotKeyPressed`，执行 `handleHotKey()`：

   - 调用 `SelectionManager.getSelectedText()` 获取当前选区文本。
   - 若无选区（nil/空白），直接返回，不唤起浮窗。

4. **选区获取**  
   `SelectionManager`：

   - 先通过 AXUIElement 读取 `kAXSelectedTextAttribute` / `kAXSelectedTextRangeAttribute`。
   - 失败则模拟 Cmd+C，并从剪贴板读取文本，随后恢复剪贴板内容。

5. **浮窗展示**  
   获取到选区后，`WindowManager.showPopupNearMouse()` 定位并展示无标题栏毛玻璃浮窗。

6. **ViewModel 注入源文本**  
   `ContentView` 调用 `TranslationViewModel.setSourceText(selected)`。

7. **翻译服务分发**  
   `ContentView.translateCurrent(engineId:)` 把请求统一委托给 `TranslationService.shared.streamTranslate(...)`（actor）。`TranslationService` 内部根据 `TranslationEngine.kind` 分流：

   - **免费引擎（google）** → `FreeTranslateService.translate(...)`（非流式 REST），把单次响应包装成单 token 的 `AsyncThrowingStream` 给 UI 统一消费。
   - **OpenAI 兼容引擎（内置或自定义）** → 解析 baseURL / apiKey 优先级（引擎级覆盖全局，否则用全局 + 默认 `https://api.openai.com/v1`），组装 `LLMService.Configuration` 后调 `LLMService.streamTranslate(...)`（SSE 流式）。
   - 所有异常在 `TranslationService` 入口统一映射为 `TranslationError`（HTTP 状态、无网络、缺 API Key 等），ViewModel 直接拿到结构化错误。

8. **UI 渲染更新**  
   ViewModel 持续更新 `translatedText`/`streamedText`，`TranslationPopupView` 作为观察者自动重绘，展示 Markdown 渲染后的结果，并支持复制、切换引擎重新翻译等交互。

---

## 3. 核心模块与逻辑 (Core Modules)

### 3.1 SelectionManager（划词模块）

文件：`Lexi/Core/System/SelectionManager.swift`

职责：

- **权限检查与申请**

  - 使用 `AXIsProcessTrustedWithOptions` 判断并可选提示用户授予"辅助功能"权限。
  - 无权限时抛出 `SelectionError.notAuthorized`，由上层展示错误并引导授权。

- **选区读取（AXUIElement）**

  - 从系统级元素 `AXUIElementCreateSystemWide()` 获取 `kAXFocusedUIElementAttribute`。
  - 优先读取 `kAXSelectedTextAttribute`。
  - 若仅有选区范围，则读取 `kAXSelectedTextRangeAttribute` 与 `kAXValueAttribute` 拼出文本。

- **兜底方案（Cmd+C + 剪贴板）**

  - 用 `CGEvent` 模拟 Cmd+C。
  - **轮询 `NSPasteboard.changeCount`**（步长 20ms、上限 400ms）等剪贴板更新——不再用固定 sleep，慢应用（Electron/Office）也能稳定拿到结果，快应用不白等。
  - 通过 `NSPasteboard` 读取新内容；恢复之前的剪贴板 snapshot（含所有 `pasteboardItems` 的多类型 data）避免破坏用户剪贴板。
  - 过滤纯空白结果。轮询超时记 `os.Logger` warning。

- **来源标注（埋点/调试用）**

  - `getSelectedTextResult()` 返回 `SelectionExtractionResult { text, source: ExtractedTextSource }`，source 取 `.axText` / `.axRange` / `.pasteboard` 之一。
  - 旧 API `getSelectedText()` 保留为薄包装，丢弃 source 字段——划词浮窗当前仍走旧 API；阅读器接入时若需要识别"是否来自 WKWebView"等场景，改用新 API。

这一层封装了不同 App 对 AX 选区支持不一致的问题，保证在主流应用中可用。

### 3.2 Translation Service（翻译服务层）

文件：`Lexi/Core/Translation/TranslationService.swift`、`Lexi/Core/Translation/LLMService.swift`、`Lexi/Core/Translation/FreeTranslateService.swift`、`Lexi/Core/Engine/TranslationEngine.swift`

设计要点：

- **引擎描述模型**  
  `TranslationEngine` 描述一次翻译所需的关键信息：

  - `id` / `displayName`
  - `kind`（`.free` 或 `.openAICompatible`）
  - `baseURL` / `apiKey` / `model`（对自定义 AI 引擎有效）
  - `isCustom`

- **策略/工厂式分发**

  - `TranslationService`（actor）是真正的分发入口，`ContentView` 只调一个 `streamTranslate(..., promptStrategy:, cache:)`。Actor 根据 `TranslationEngine.kind` 选择不同服务实现：
    - **FreeTranslateService**：同步 REST，返回完整字符串；actor 内部用 `AsyncThrowingStream` 包成单 token 流，保持 UI 侧消费接口一致。
    - **LLMService**：OpenAI-compatible SSE 流式输出，返回 `AsyncThrowingStream<String, Error>`，actor 在透传时把底层 `LLMServiceError` / `URLError` 映射为 `TranslationError`。
  - 这种分发逻辑等价于一个轻量的 Factory + Strategy 组合：  
    `engineKind → strategy(service)`。
  - baseURL / apiKey 走 "引擎级覆盖 → 全局兜底 → 默认值" 的三级 fallback，自定义引擎只填部分字段也能跑起来。
  - **段落级入口**：`translateParagraph(...)` 复用 `streamTranslate` + `ParagraphPromptStrategy` 收齐返回完整字符串，专为阅读器场景准备；调用方需自带 `TranslationCache`。

- **Prompt 策略（`TranslationPromptStrategy`）**

  文件：`Lexi/Core/Translation/TranslationPromptStrategy.swift`

  - 协议拆开了"翻译什么"和"怎么翻"——`LLMService` 不再硬编码 prompt，由调用方传入 strategy。
  - 内置实现：
    - `WordOrPhrasePromptStrategy`：划词浮窗用，conforms `SourceAwareTranslationPromptStrategy`（多一个 text 参数）——单词级输入会切到"字典 JSON 卡片"模式，由 `LanguageDetector.isEnglishWordQuery` 判别。
    - `ParagraphPromptStrategy`：阅读器段落用，当前是朴素 prompt，后续会迭代。
  - 每个 strategy 必须暴露 `promptVersion: String`，作为 `TranslationCacheKey` 的一部分——prompt 改版自动让旧缓存失效。

- **翻译缓存（`TranslationCache`）**

  文件：`Lexi/Core/Translation/TranslationCache.swift`

  - 协议接口：`get(_:) async -> String?` / `set(_:value:) async`。
  - `TranslationCacheKey` 由 `(textHash, sourceLanguage, targetLanguage, engineID, modelID, promptVersion)` 组成；text 用 SHA256 哈希避免长 key 占用内存。
  - 已实现 `InMemoryTranslationCache`（actor）。阅读器章节级翻译需要 SQLite 后端，待 Reader 开工时补。
  - **取消即不写**：`TranslationService.mapErrors` 同时监听 `Task.isCancelled`（producer 端取消）和 `continuation.onTermination(.cancelled)`（下游消费者 break 出 for-await），两路任一触发都跳过 cache 写入——避免被截断的部分流污染缓存。回归覆盖在 `LexiTests/TranslationServiceCacheTests`。

- **流式 LLM 实现（LLMService）**

  - 通过 `URLSession.shared.bytes(for:)` 读取 SSE。
  - 按行解析 `data:` payload，解码 `choices[].delta.content` 并逐 token `yield`。
  - ViewModel 将 token 拼接到 UI，实现"边翻译边显示"。
  - 支持用户输入 host-only baseURL（自动补 `/v1/chat/completions`），也支持粘贴完整 endpoint。
  - 系统 prompt 由 `Configuration.promptStrategy` 提供；若 strategy conforms `SourceAwareTranslationPromptStrategy`，发请求时会带上 source text 让 strategy 自己判别是否切换 prompt（用于单词卡分支）。

- **非流式免费引擎（FreeTranslateService）**
  - 以 `engineId` switch 选择具体实现（当前仅 Google；Microsoft 已下线，老配置由 `EngineStore.normalizedEngineId` 在解析引擎时迁到 google）。
  - 对外暴露统一 `translate(engineId:sourceLanguage:targetLanguage:text:)`。

- **语言检测（`LanguageDetector`）**

  文件：`Lexi/Core/Translation/LanguageDetector.swift`

  - 无状态静态方法集合：`resolve(...)`（zh/en 自动 swap）、`detectPrimaryLanguageCode(for:)`（`NLLanguageRecognizer` + Unicode 范围兜底）、`isEnglishWordQuery(_:)`（单词模式判别）。
  - `isEnglishWordQuery` 被 `WordOrPhrasePromptStrategy` 和 `TranslationViewModel.parseWordExplanationIfPossible` **共用同一份实现**——别再各自抄一遍。

### 3.3 WindowManager（窗口管理）

文件：`Lexi/Core/System/WindowManager.swift`

职责：

- **窗口形态**

  - 绑定 SwiftUI Host 的 `NSWindow`，设置为 `.borderless`、透明背景、毛玻璃由 SwiftUI `Material` 渲染。
  - 窗口层级为 `.floating`，可跨 Space 显示。

- **定位逻辑（跟随鼠标 + 边缘自适应）**

  - `showPopupNearMouse()` 读取当前鼠标位置 `NSEvent.mouseLocation`。
  - 默认在鼠标右下偏移显示。
  - 使用屏幕 `visibleFrame` 进行边界检测：
    - 若右侧或下侧越界，则回退到可见区域内。
    - 若下方空间不足，则显示在鼠标上方。

- **点击外部自动关闭**
  - 使用本地/全局 `NSEvent` monitor 捕获鼠标点击。
  - 点击非 Lexi 窗口区域时 `hidePopup()` 并发出 `.lexiPopupDismissRequested`，由 `ContentView` 清理 ViewModel 内容。

---

## 4. 关键代码结构 (Key Code Structure)

入口与协调：

- `Lexi/LexiApp.swift`  
  SwiftUI App 入口，声明主 Scene、`MenuBarExtra` 与 Settings Scene。
- `Lexi/AppDelegate.swift`  
  AppKit 生命周期补充：启动注册全局快捷键、预请求辅助功能权限、初始化隐藏浮窗。
- `Lexi/ContentView.swift`  
  应用主协调层：监听热键、获取选区、展示浮窗、分发翻译服务、响应模型切换与关闭通知。

Core/Translation（翻译核心）：

- `Lexi/Core/Translation/TranslationService.swift` — actor 策略分发入口，统一错误映射、缓存读写、取消处理。
- `Lexi/Core/Translation/LLMService.swift` — OpenAI 兼容 SSE 流式翻译；prompt 由 strategy 提供。
- `Lexi/Core/Translation/FreeTranslateService.swift` — 免费引擎 REST 翻译（当前仅 Google）。
- `Lexi/Core/Translation/TranslationPromptStrategy.swift` — `TranslationPromptStrategy` 协议 + `WordOrPhrasePromptStrategy` / `ParagraphPromptStrategy` 实现。
- `Lexi/Core/Translation/TranslationCache.swift` — `TranslationCache` 协议 + `TranslationCacheKey` + `InMemoryTranslationCache`。
- `Lexi/Core/Translation/LanguageDetector.swift` — 语言识别、zh/en swap、单词模式判别。

Core/Engine（引擎与配置）：

- `Lexi/Core/Engine/EngineStore.swift` — 内置 + 自定义引擎集合、`normalizedEngineId`（含 `microsoft → google` 迁移）。
- `Lexi/Core/Engine/TranslationEngine.swift` — 引擎数据模型。
- `Lexi/Core/Engine/ModelOptions.swift` / `LanguageOptions.swift` — 内置模型 / 语言常量。
- `Lexi/Core/Engine/APIKeyStore.swift` — 全局 API Key Keychain 存储（含 `UserDefaults` 一次性迁移）。

Core/System（系统能力）：

- `Lexi/Core/System/SelectionManager.swift` — 选区提取：AXUIElement 优先 + Cmd+C 剪贴板兜底（轮询 `changeCount`），暴露 `ExtractedTextSource`。
- `Lexi/Core/System/HotKeyManager.swift` + `Lexi/Core/System/HotKey.swift` — 全局快捷键注册与持久化。
- `Lexi/Core/System/WindowManager.swift` — 浮窗生命周期、跟随鼠标定位、点击外部关闭。
- `Lexi/Core/System/TextToSpeechService.swift` — 单词卡 TTS 朗读。
- `Lexi/Core/System/LaunchAtLoginManager.swift` — 开机自启切换。

Popup（划词浮窗 feature）：

- `Lexi/Popup/TranslationPopupView.swift` — 浮窗 UI：毛玻璃容器、Markdown 渲染、复制按钮、模型/引擎菜单、设置入口。
- `Lexi/Popup/SettingsView.swift` — 设置页：源/目标语种、快捷键录制、内置引擎、全局 OpenAI、自定义引擎管理。
- `Lexi/Popup/HotKeyRecorderField.swift` — 快捷键录制 UI 控件。
- `Lexi/Popup/TranslationViewModel.swift` — 翻译状态机：维护输入/输出/错误/加载状态，处理流取消。
- `Lexi/Popup/WordExplanationView.swift` + `Lexi/Popup/WordExplanation.swift` — 单词卡 UI 与数据模型。
- `Lexi/Popup/ErrorBannerView.swift` — 错误 banner（含跳辅助功能权限设置）。

Reader（待实施）：

- `Lexi/Reader/` — 占位目录。EPUB 阅读器代码（解析、WKWebView 渲染、章节级段落翻译协调器、SQLite 缓存）落地于此。

Shared/Utilities（跨层小工具）：

- `Lexi/Shared/Utilities/KeychainHelper.swift` — Keychain 读写封装。
- `Lexi/Shared/Utilities/Notifications.swift` — `Notification.Name` 常量。
- `Lexi/Shared/Utilities/AppKitHelpers.swift` / `WindowAccessor.swift` — SwiftUI ↔ AppKit 桥接。

测试：

- `LexiTests/` — XCTest target。当前覆盖：`LanguageDetector`、`EngineStore` 迁移、`TranslationCacheKey` 哈希、`TranslationService` 取消即不写缓存。

---

## 5. 扩展性指南 (Extensibility Guide)

### 5.1 如何添加新模型（如 Claude / Gemini）

**情况 A：新模型提供 OpenAI 兼容接口**  
（例如 Claude/Gemini 的兼容代理或统一网关）

1. 在 `Lexi/Core/Engine/ModelOptions.swift` 的 `defaults` 中新增模型 id。
2. 如需在菜单中分组或显示更友好的名称，可在 `EngineStore.builtInEngines` 或 `TranslationEngine.displayName` 中补充。
3. 不需要改动服务层；`LLMService` 会按 OpenAI-compatible 协议工作。
4. 若需要专属 prompt（如某模型对特定指令更稳），新建一个 `TranslationPromptStrategy` 实现并在调用处传入，**不要硬编码进 `LLMService`**。

**情况 B：新模型是非兼容协议**

1. 在 `Lexi/Core/Engine/TranslationEngine.swift` 的 `TranslationEngine.Kind` 中新增一个 kind（例如 `.claude`）。
2. 新建对应 Service（`Lexi/Core/Translation/ClaudeService.swift`），定义统一的 `translate/streamTranslate` 接口。
3. 在 `Lexi/Core/Translation/TranslationService.swift:streamTranslate(...)` 增加分支，将该 kind 分发到新 Service（注意把非流式响应也包成 `AsyncThrowingStream` 以保持 UI 消费接口统一）。
4. 在 `EngineStore` 或 `ModelOptions` 注册为内置引擎，以出现在浮窗菜单与设置页中。
5. 如有新的错误类型，扩展 `TranslationError.from(_:)`，让错误能正确映射到现有 banner UI。
6. 注意 cache key 包含 `engineID` + `modelID` + `promptVersion`——新引擎/模型不会撞老缓存，无需手动失效。

### 5.2 如何添加新功能（Plugin 架构：OCR / TTS）

建议以 **Service + ViewModel 扩展点** 方式接入：

- **OCR（识别图片文字）**

  - 接入点：`ContentView.handleHotKey()` 的“获取源文本”步骤之前或并行。
  - 新建 `OCRService`（可用 Vision/ScreenCaptureKit），提供 `recognizeText(from:)`。
  - ViewModel 增加一个输入来源枚举（selection / ocr），方便未来在 UI 上切换。

- **TTS（语音朗读）**
  - 接入点：ViewModel 翻译完成后。
  - 新建 `TTSService`（`AVSpeechSynthesizer`），在 `TranslationPopupView` 提供“朗读”按钮调用。

若后续要真正插件化，可定义协议：

```swift
protocol LexiPlugin {
    var id: String { get }
    func run(input: PluginInput) async throws -> PluginOutput
}
```

并在 `ContentView` 或 ViewModel 中维护一个插件链（pre-translate / post-translate）。

---

## 6. 待办与路线图 (Roadmap)

已完成：

- ~~**安全存储**：API Key 迁移到 Keychain。~~ 已通过 `APIKeyStore` + `KeychainHelper` 完成，启动时一次性把旧 `UserDefaults("apiKey")` 迁入 Keychain。
- ~~**错误结构化**：服务层错误集中映射。~~ 由 `TranslationError` 统一定义 HTTP / 网络 / 缺 Key / 不支持引擎等分类，`ErrorBannerView` 消费。
- ~~**选区兜底鲁棒性**~~：固定 180ms sleep 已改为轮询 `changeCount`（上限 400ms），慢应用也能稳定拿到；超时记 `os.Logger` warning。
- ~~**流式取消**~~：`TranslationViewModel.streamTranslate` 持有 `activeTask` 并在新调用时取消旧 task；`TranslationService.mapErrors` 监听双向取消信号（Task 取消 + 下游 stream 终止），取消时跳过 cache 写入。
- ~~**模块化重构**~~：目录按 `Core/{Translation,Engine,System}` + `Popup` + `Reader` + `Shared/Utilities` 重新组织；prompt 抽出 `TranslationPromptStrategy`、缓存抽出 `TranslationCache` 协议、语言检测抽出 `LanguageDetector`。
- ~~**测试 Target**~~：已加 `LexiTests/`，smoke level 覆盖语言检测、引擎迁移、缓存 key 哈希、取消即不写缓存的回归。

仍待改进：

- **阅读器（EPUB）**：`Lexi/Reader/` 占位中，待实施。形态：原文段下方注入小字译文，章节级段落并发翻译 + SQLite 缓存，保留划词浮窗作为深度查词入口。MVP 工程量预估 3-5 周。
- **SQLite TranslationCache 实现**：当前仅 `InMemoryTranslationCache`，阅读器接入前需要按书 ID + 段落 hash 持久化的 SQLite 实现。
- **段落 prompt 迭代**：`ParagraphPromptStrategy` 目前是朴素版本，需结合实际章节文本调优；prompt 版本号变化会自动让旧 cache 失效。
- **错误处理 UX**：错误 banner 已有，但无显式重试按钮；网络抖动场景需要手动切换引擎才能重试。阅读器场景还需单段重试 UI。
- **引擎管理增强**：自定义引擎可加入导入/导出、排序、图标等能力。
- **快捷键冲突检测**：录制快捷键时检测系统/应用冲突，并提供可视化提示。
- **测试覆盖扩展**：当前只是 smoke level。需补 `LLMService` SSE 解析、`TranslationError.from(_:)` 映射边界等。
- **权限引导**：对辅助功能权限的首次引导可以更明确（如弹窗说明 + 跳转系统设置）。
- **WindowGroup 复用 hack**：当前用默认 `WindowGroup` 当浮窗宿主，靠 `AppDelegate` 启动 200ms 后 `hidePopup()` 隐藏。冷启动可能闪一下，且 macOS 仍可能由窗口恢复触发额外实例。阅读器加入后需重新设计 Scene 结构——`MenuBarExtra`（划词）+ `Window` 或 `DocumentGroup`（阅读器）共存。
- **分发**：brew cask 发布（需 Developer ID 签名 + notarize 流水线 + GitHub Release 自动化）。
