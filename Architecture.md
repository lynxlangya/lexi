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
- **多引擎支持**：同时兼容 OpenAI/DeepSeek 等流式 LLM 以及 Google/Microsoft 免费翻译引擎。
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
  - 代表文件：`Lexi/ContentView.swift`、`Lexi/Views/TranslationPopupView.swift`、`Lexi/Views/SettingsView.swift`

- **ViewModel**

  - 维护翻译过程的状态（源文本、翻译结果、流式 token、错误信息、加载状态）。
  - 提供 `translate` / `streamTranslate` 等动作，协调服务层输出到 UI。
  - 代表文件：`Lexi/Models/TranslationViewModel.swift`

- **Model / Service**
  - Model 描述引擎、语言、配置等数据结构。
  - Service 负责系统能力访问（选区、窗口、快捷键）与网络翻译请求。
  - 代表文件：
    - Models：`Lexi/Models/TranslationEngine.swift`、`Lexi/Models/EngineStore.swift`、`Lexi/Models/LanguageOptions.swift`、`Lexi/Models/ModelOptions.swift`、`Lexi/Models/HotKey.swift`
    - Services：`Lexi/Services/SelectionManager.swift`、`Lexi/Services/LLMService.swift`、`Lexi/Services/FreeTranslateService.swift`、`Lexi/Services/WindowManager.swift`、`Lexi/Services/HotKeyManager.swift`

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
   `ContentView.translateCurrent(engineId:)` 根据当前 `selectedEngineId`：

   - **免费引擎（google/microsoft）** → `FreeTranslateService.translate(...)`（非流式 REST）
   - **内置 AI 模型（OpenAI 兼容）** → `LLMService.streamTranslate(...)`（SSE 流式）
   - **自定义 AI 引擎** → 从 `EngineStore.loadCustomEngines()` 取 baseURL/model/apiKey 组装 `LLMService.Configuration`，再流式翻译

8. **UI 渲染更新**  
   ViewModel 持续更新 `translatedText`/`streamedText`，`TranslationPopupView` 作为观察者自动重绘，展示 Markdown 渲染后的结果，并支持复制、切换引擎重新翻译等交互。

---

## 3. 核心模块与逻辑 (Core Modules)

### 3.1 SelectionManager（划词模块）

文件：`Lexi/Services/SelectionManager.swift`

职责：

- **权限检查与申请**

  - 使用 `AXIsProcessTrustedWithOptions` 判断并可选提示用户授予“辅助功能”权限。
  - 无权限时抛出 `SelectionError.notAuthorized`，由上层展示错误并引导授权。

- **选区读取（AXUIElement）**

  - 从系统级元素 `AXUIElementCreateSystemWide()` 获取 `kAXFocusedUIElementAttribute`。
  - 优先读取 `kAXSelectedTextAttribute`。
  - 若仅有选区范围，则读取 `kAXSelectedTextRangeAttribute` 与 `kAXValueAttribute` 拼出文本。

- **兜底方案（Cmd+C + 剪贴板）**
  - 用 `CGEvent` 模拟 Cmd+C。
  - 通过 `NSPasteboard` 读取新内容；若剪贴板发生变化，恢复之前的 snapshot（避免破坏用户剪贴板）。
  - 过滤纯空白结果。

这一层封装了不同 App 对 AX 选区支持不一致的问题，保证在主流应用中可用。

### 3.2 Translation Service（翻译服务层）

文件：`Lexi/Services/LLMService.swift`、`Lexi/Services/FreeTranslateService.swift`、`Lexi/Models/TranslationEngine.swift`

设计要点：

- **引擎描述模型**  
  `TranslationEngine` 描述一次翻译所需的关键信息：

  - `id` / `displayName`
  - `kind`（`.free` 或 `.openAICompatible`）
  - `baseURL` / `apiKey` / `model`（对自定义 AI 引擎有效）
  - `isCustom`

- **策略/工厂式分发**

  - `ContentView.translateCurrent(engineId:)` 根据 `engineId` 与 `TranslationEngine.kind` 选择不同服务实现：
    - **FreeTranslateService**：同步 REST，返回完整字符串。
    - **LLMService**：OpenAI-compatible SSE 流式输出，返回 `AsyncThrowingStream<String, Error>`。
  - 这种分发逻辑等价于一个轻量的 Factory + Strategy 组合：  
    `engineId → strategy(service)`。

- **流式 LLM 实现（LLMService）**

  - 通过 `URLSession.shared.bytes(for:)` 读取 SSE。
  - 按行解析 `data:` payload，解码 `choices[].delta.content` 并逐 token `yield`。
  - ViewModel 将 token 拼接到 UI，实现“边翻译边显示”。
  - 支持用户输入 host-only baseURL（自动补 `/v1/chat/completions`），也支持粘贴完整 endpoint。

- **非流式免费引擎（FreeTranslateService）**
  - 以 `engineId` switch 选择具体实现（Google / Microsoft）。
  - 对外暴露统一 `translate(engineId:sourceLanguage:targetLanguage:text:)`。

### 3.3 WindowManager（窗口管理）

文件：`Lexi/Services/WindowManager.swift`

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

- `Lexi/LexiApp.swift`  
  SwiftUI App 入口，声明主 Scene 与 Settings Scene。

- `Lexi/AppDelegate.swift`  
  AppKit 生命周期补充：启动注册全局快捷键、预请求辅助功能权限、初始化隐藏浮窗。

- `Lexi/ContentView.swift`  
  应用主协调层：监听热键、获取选区、展示浮窗、分发翻译服务、响应模型切换与关闭通知。

- `Lexi/Models/TranslationViewModel.swift`  
  翻译状态机：维护输入/输出/错误/加载状态，封装流式与非流式翻译动作。

- `Lexi/Views/TranslationPopupView.swift`  
  浮窗 UI：毛玻璃容器、结果 Markdown 渲染、复制按钮、模型/引擎菜单、设置入口。

- `Lexi/Views/SettingsView.swift`  
  设置页：源/目标语种、快捷键录制、内置引擎选择、全局 OpenAI 配置、自定义 AI 引擎增删改。

- `Lexi/Services/SelectionManager.swift`  
  选区提取：AXUIElement 优先 + Cmd+C 剪贴板兜底。

- `Lexi/Services/LLMService.swift`  
  OpenAI 兼容流式翻译：SSE 解析为 AsyncThrowingStream。

- `Lexi/Services/FreeTranslateService.swift`  
  免费引擎翻译：Google / Microsoft REST API。

- `Lexi/Services/WindowManager.swift`  
  浮窗生命周期、定位与点击外部关闭。

- `Lexi/Services/HotKeyManager.swift` + `Lexi/Models/HotKey.swift` + `Lexi/Views/HotKeyRecorderField.swift`  
  全局快捷键注册、持久化与录制 UI。

---

## 5. 扩展性指南 (Extensibility Guide)

### 5.1 如何添加新模型（如 Claude / Gemini）

**情况 A：新模型提供 OpenAI 兼容接口**  
（例如 Claude/Gemini 的兼容代理或统一网关）

1. 在 `Lexi/Models/ModelOptions.swift` 的 `defaults` 中新增模型 id。
2. 如需在菜单中分组或显示更友好的名称，可在 `EngineStore.builtInEngines` 或 `TranslationEngine.displayName` 中补充。
3. 不需要改动服务层；`LLMService` 会按 OpenAI-compatible 协议工作。

**情况 B：新模型是非兼容协议**

1. 在 `Lexi/Models/TranslationEngine.swift` 的 `TranslationEngine.Kind` 中新增一个 kind（例如 `.claude`）。
2. 新建对应 Service（`Lexi/Services/ClaudeService.swift`），定义统一的 `translate/streamTranslate` 接口。
3. 在 `Lexi/ContentView.swift:translateCurrent(engineId:)` 增加分支，将该 kind 分发到新 Service。
4. 在 `EngineStore` 或 `ModelOptions` 注册为内置引擎，以出现在浮窗菜单与设置页中。

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

当前技术债与改进方向：

- **安全存储**：API Key 目前存于 `@AppStorage`（UserDefaults），需迁移到 Keychain。
- **错误处理**：服务层错误展示仍偏粗糙，可增加重试、网络超时提示与更友好的 UI 文案。
- **性能与缓存**：同一段文本重复翻译可做短期缓存，减少请求。
- **引擎管理增强**：自定义引擎可加入导入/导出、排序、图标等能力。
- **快捷键冲突检测**：录制快捷键时检测系统/应用冲突，并提供可视化提示。
- **测试体系**：目前无测试 Target，可逐步引入 `LexiTests/` 覆盖服务与 ViewModel 逻辑。
- **权限引导**：对辅助功能权限的首次引导可以更明确（如弹窗说明 + 跳转系统设置）。
