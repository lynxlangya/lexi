# AI Translate macOS App · Tasks

## Phase 1 · UI 浮窗与毛玻璃

- [ ] 创建 `TranslationPopupView`，包含：
  - [ ] 毛玻璃背景（SwiftUI `.background(.ultraThinMaterial)` 或自定义 VisualEffectView）
  - [ ] 圆角 12
  - [ ] 头部：Logo + 文本“AI Translate” + 右侧设置按钮
  - [ ] 中间内容区域占位符
  - [ ] 底部工具栏：复制按钮、模型选择菜单
- [ ] 在 `WindowGroup` 中配置为无标题栏浮动窗口，背景透明

## Phase 2 · 划词与快捷键监听

- [ ] 引入全局快捷键管理（CGEvent / HotKey 库）
- [ ] 创建 `SelectionManager`，实现 `getSelectedText() async throws -> String?`
- [ ] 使用 `AXUIElement` 获取当前焦点应用选中文本
- [ ] 检查并请求辅助功能权限，如果未授权弹出提示引导用户到系统设置

## Phase 3 · LLM API 与流式输出

- [ ] 创建 `LLMService`，支持 OpenAI 兼容接口（包括 DeepSeek）
- [ ] 使用 `async/await`，支持流式返回
- [ ] 方法签名包含：`apiKey`、`modelName`、`prompt`、`sourceText`
- [ ] 对外暴露类似 `streamTranslate` 接口，支持通过闭包回调逐 token 更新 UI

## Phase 4 · 窗口定位与设置

- [ ] 使用 `NSEvent.mouseLocation` 获取鼠标坐标
- [ ] 计算窗口位置显示在鼠标右下角，并做屏幕边缘边界处理
- [ ] 提供 `SettingsView`，使用 `AppStorage` 持久化 `apiKey` 和 `selectedModel`
- [ ] 将 Settings 入口与主浮窗联动

## Phase 5 · Markdown 渲染与细节打磨

- [ ] 集成 Markdown 渲染（如 MarkdownUI 或 AttributedString）
- [ ] 对翻译结果支持 Markdown 显示、代码块、加粗
- [ ] 增加“一键复制结果”功能
- [ ] 增加 Loading 状态与加载动画
