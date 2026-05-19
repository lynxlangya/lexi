# Lexi · Design Brief

> 单一可信源：[`design/`](design/) 目录下的 prototype 是规格本身。本文件做信息架构和工程交接的桥，不重复 prototype 已经定死的像素值。**遇到本文件和 prototype 冲突，以 prototype 为准。**

---

## 0. v1 MVP 范围（已锁 · 2026-05-19）

用户 6 条决议，工程从这里开始打：

| # | 决议 | 工程后果 |
|---|---|---|
| 1 | **Reader 只走 Quiet 方向**；**段落样式只做 A (字号 demote)**；**浮窗只做 B · Power** | 删除 Composed 路径、B/C 段落样式、A 浮窗变体；设置里的 "译文视觉强度" / "浮窗方向" toggle 一起拿掉 |
| 2 | **仅支持 EPUB** | 引一个 EPUB 解析库（候选 [`ZIPFoundation`](https://github.com/weichsel/ZIPFoundation) + 自写 OPF/NCX/Nav parser，或 [`SwiftSoup`](https://github.com/scinfu/SwiftSoup) 处理 XHTML 章节）。不引 PDF / MOBI / AZW3 |
| 3 | **BYOK only**，无用户系统、无后端、无托管订阅 | 不建账户层；API Key 全部 Keychain 本地存；启动无登录 |
| 4 | **数据全本地**，**v1 不引 Core Data，也不引 CloudKit** | 删 Xcode 模板自带的 [`lexi/Persistence.swift`](lexi/Persistence.swift) 和 [`lexi/lexi.xcdatamodeld`](lexi/lexi.xcdatamodeld)；选 GRDB 或 SQLite.swift 做单一持久层；设置面板的 "iCloud 同步" toggle 删除 |
| 5 | **生词本 v1 = 收藏 + 本地列表**，不做 SRS 复习 | menu-bar 下拉里 "今日复习 (5)" 高亮项 v1 不接逻辑（建议先隐藏或灰显，避免假承诺） |
| 6 | **不内嵌本地词典**，划词查询统一走引擎 | 浮窗引擎 pill 里 `Dict` 选项删除 |
| 7 | **引擎只 3 个预设：OpenAI · Anthropic · DeepSeek**；**每个都要用户自填 API Key + Model 名**；**v1 不做"自定义引擎"模块** | (a) 设置→引擎 API Keys 三行：OpenAI / Anthropic / DeepSeek（**DeepL / Google 整体出局**）；(b) 每行控件改为 `[Key 输入框] + [Model 名输入/select] + 测试`；(c) 设置→引擎→"自定义引擎"整个 section 删除；(d) 段落引擎 + 划词引擎默认 select options 全部改为 `OpenAI / Anthropic / DeepSeek`；(e) Reader/MenuBar 浮窗 pill 改为 `GPT / Claude / DeepSeek`；(f) 整段落顶栏 ⚙ engine 菜单同步 |
| 8 | **段落引擎中途切换不重译已缓存段** | 已缓存段保留旧译文（旧引擎），只对后续未翻译段用新引擎；UI 不弹确认 |
| 9 | **EPUB 封面：自带优先，缺失 fallback 排印** | EPUB 解析阶段提 `cover.xhtml/jpg`；有 → 渲染原图（合适圆角 + 投影一致）；无 → 走 [`prototype-shelf.jsx`](design/prototype-shelf.jsx) 的排印封面（`cover.bg + cover.ink` 双色） |
| 10 | **浮窗 B 的"备选译文" inset v1 隐藏** | [`menubar-popup-v2.jsx:356`](design/menubar-popup-v2.jsx:356) `alt` 字段 + "备选 · DeepL" inset 都不渲染 |
| 11 | **浮窗 B 的"发送到 Lexi 阅读器"按钮 v1 隐藏** | [`menubar-popup-v2.jsx`](design/menubar-popup-v2.jsx) `WordB / SentenceB` 里 `onSend` 按钮删 |
| 12 | **朗读 ⌘. 接 `AVSpeechSynthesizer`** | 系统 TTS，离线、免 key；浮窗 / Reader 的 speaker icon 都接此 |

下文凡有可切换 toggle / 多方向并列处，**以本节为准**剪掉。其余 prototype 像素 / 交互照搬。

### Engine 配置 UI 细节（决议 7 展开）

每个预设引擎在设置→引擎 tab 里是一行，结构：

```
[● 状态点]  OpenAI                              [●●●●●●●●●●N7B2]  [gpt-4-turbo ▾]  [测试]  [⋯]
            GPT-4 / GPT-3.5 / GPT-5            ← API Key (SecureField)  Model picker
```

- **API Key field**：`SecureField` + autofill；Keychain 持久化；状态点：绿 = 已设置且测试过通；灰 = 未设置；红 = 测试失败。
- **Model field**：`TextField` + placeholder（OpenAI: `gpt-4-turbo` / Anthropic: `claude-sonnet-4-6` / DeepSeek: `deepseek-chat`），不强校验。理由：模型迭代快，写死 enum 上线第二个月就过期。
- **"测试"按钮 = 轻量探活**，不发真翻译：
  - **OpenAI** / **DeepSeek**：`GET /v1/models` —— 200 = key 有效；再在返回的 model 列表里 grep 用户填的 model 名，命中 → 绿；未命中 → 黄（key 通过但 model 名可能错）。
  - **Anthropic**：没有 list-models 端点 → 用最便宜的 Haiku 发 1-token request（成本 ≈ $0.0001），200 即 OK；如果用户填的是 Opus/Sonnet，也照样这样测（成本几乎一致）。
  - 测试结果（状态点颜色 + 时间戳）落 `EngineConfig.lastTestedOK`，下次启动直接显示历史结果，不强制重测。

---

## 1. 产品一句话

**Lexi 是一个 macOS 桌面应用**，给中文读者读英文文学用 —— 在阅读器里把英文原文与中文译文逐段并排展示（译文由 LLM/翻译引擎按需生成并缓存），同时在 menu-bar 提供"全局划词翻译"浮窗，让用户在任何 app（Safari、Mail、Notes…）选中英文也能立刻得到 Lexi 风格的单词卡 / 整句卡。

**核心信念**（写在 [design/app.jsx:160](design/app.jsx:160) 段落样式注释里）：
- 译文是辅助不是主角；原文为主，译文 80% 时间在视野边缘。
- 视觉密度尽量低，目标是 1–2 小时连续阅读不疲劳。
- 没有任何拟物（皮革书架、卷边书页等）。封面是排印矩形，glyph 是抽象条形。

---

## 2. 两个产品面 (Surfaces)

| | **Reader 主窗口** | **MenuBar 浮窗** |
|---|---|---|
| **入口** | Dock 图标 / `⌘⇧K` 全局唤起 | 系统状态栏 Lexi 图标 / `⌘⇧L` 划词 |
| **形态** | 标准 `NSWindow` 1200×760+ | `NSPanel` (.nonactivatingPanel)，跟随选区 |
| **聚焦** | 通读、章节切换、翻译预取 | 即时单词 / 整句解释，不打断主任务 |
| **当前 prototype** | [Lexi Prototype.html](design/Lexi%20Prototype.html) | [Lexi MenuBar.html](design/Lexi%20MenuBar.html) |
| **当前 jsx 入口** | `prototype.jsx` | `menubar-app.jsx` |

两面共享：tokens、字典模型、引擎模型、生词本数据、设置面板。Power 浮窗有 "发送到 Lexi 阅读器" 按钮、menu-bar 下拉里有 "打开阅读器…"，两面互通。

---

## 3. 核心交互闭环

来自 [design/app.jsx:353 FlowDiagram](design/app.jsx:353)：

```
01 打开 EPUB     →  02 预取章节     →  03 阅读       →
   拖拽 / ⌘O          当前 + 下一章      原文为主
   书架记录           并行翻译           译文边缘可见

→  04 划词       →  05 加生词       →  06 切章
   ⌘⇧L              + 收入             侧栏 / 翻页
   浮窗跟随鼠标       v2: 复习卡         预取下一章
```

---

## 4. 设计基底 (Tokens)

权威定义在 [design/tokens.jsx](design/tokens.jsx) `TOKENS / SPACING / RADII`，工程接入按 [design/app.jsx:64](design/app.jsx:64) 提示：在 Asset Catalog 建 `Lexi/Paper`、`Lexi/Ink` 等 named colors，开 Any / Dark 两套 appearance，系统跟随暗色模式。

### 4.1 颜色（暖色双模）

| 类 | Light (Paper) | Dark (Candlelit) | 用途 |
|---|---|---|---|
| `bg` | `#f5f1e8` | `#1c1915` | 页面底色 |
| `bgRaised` | `#fbf8f1` | `#23201a` | 侧栏、浮窗、卡片 |
| `bgInset` | `#ede7d8` | `#16140f` | 搜索框、代码块、底色译文 |
| `chrome` | `#f1ede2` | `#1f1c17` | 顶栏、底栏（不透明，避免 backdrop-filter 兼容坑） |
| `ink` | `#1f1b15` | `#ebe3d0` | 原文、标题 |
| `ink2` | `#7a7163` | `#8e8472` | **中文译文**（比 ink 淡 28-32%，关键阅读色） |
| `ink3` | `#a59c89` | `#6a6353` | chrome 标签、提示 |
| `ink4` | `#c8bfac` | `#3f3a30` | disabled、分隔 |
| `accent` | `#b35c2c` | `#d68a5a` | **铜色**，唯一重音色，只用在：当前章节高亮、选区、链接、翻译中状态 |

⚠ **重音色用得极克制**。原型里 4 个可选 swatch（铜 / 琥珀 / 橄榄棕 / 砖红）只是 [design/prototype.jsx:29 ACCENTS](design/prototype.jsx:29) 的 Tweaks，落到产品里默认就锁第一个。

### 4.2 字体

```
SERIF (en 正文 + 标题) : "New York", "Charter", "Iowan Old Style", Georgia
SANS  (UI)            : -apple-system, "SF Pro Text", "SF Pro Display"
ZH    (中文译文)       : "PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC"
MONO  (技术性元数据)    : "SF Mono", ui-monospace, Menlo
```

**注意**：[design/app.jsx:77](design/app.jsx:77) 强调 —— 在 SwiftUI 里 **不要** 用 `.body / .system`，必须 `.font(.custom("NewYork-Regular", size: 17)).lineSpacing(17 * 0.72)`。iOS-Books 的版面靠的就是手工字号 + 行距。

字号档（[design/tokens.jsx:125 TypeSpecimen](design/tokens.jsx:125)）：

| 角色 | 字号 / 行高 | 字族 |
|---|---|---|
| EN body | 17 / 29 (1.72) | SERIF |
| ZH body | 13.5 / 24 (1.78), letter-spacing .01em | ZH |
| H1 | 28 / 34 (1.2), tracking -.012em | SERIF |
| H2 | 20 / 28 (1.4) | SERIF |
| UI | 13 / 18 | SANS |
| Caption | 11 | SANS uppercase tracking .04em |
| Mono | 11 | MONO |

### 4.3 节律与尺寸

```
content-max     660 pt   阅读列最大宽
window-pad      80 pt    侧 padding（top 56-64 / bottom 48-96）
para-gap        28 pt    段间距（en+zh 视为一个单元）
en→zh gap       6 pt     段内 en 与对应 zh 的距离
radius/window   10 pt
radius/control  5 pt
```

### 4.4 动画

仅 3 个全局 keyframes（[design/Lexi Prototype.html:16](design/Lexi%20Prototype.html:16)）：

- `lexiShimmer` —— skeleton 占位条，1.6s linear infinite
- `lexiSpin` —— 翻译中 spinner，1.2s linear infinite
- `lexiPopIn` —— 浮窗 / 菜单 / Toast 出现，140-180ms ease-out，translateY(-4)→0 + scale(.985→1)

---

## 5. Reader 主窗口

[Lexi Prototype.html](design/Lexi%20Prototype.html) ⇒ `tweaks-panel + tokens + reader + chapters + prototype-{popups,parts,shelf,settings} + prototype`

### 5.1 窗口骨架

```
┌─ 44pt TitleBar  ─────────────────────────────────────────────────┐
│ 🔴🟡🟢   │      Book · Chapter III · 3/9       │ ▢ A- A+ ⌐ ⚙ ☾ ⋯  │
├──────────┬─────────────────────────────────────────────────────────┤
│ ◁ 书架   │                                                          │
│ Book name│  ┌───────────────────────────────────────────────┐       │
│ Author   │  │  CHAPTER III                                   │       │
│  ─────   │  │  There was music from my neighbor's house…    │       │
│ I  ✓     │  │  整个夏夜，邻家始终乐声不息。                   │       │
│ II ✓     │  │  (max 660pt)                                   │       │
│▌III      │  │                                                │       │
│ IV       │  └───────────────────────────────────────────────┘       │
│ V        │                                                          │
│ …        │                                                          │
│ ─────    │                                                          │
│ 全书 38% │                                                          │
├──────────┴─────────────────────────────────────────────────────────┤
│■■■■■■■■■■■░░░░░░░░░░  ← 1pt hairline 进度条                       │
├────────────────────────────────────────────────────────────────────┤
│ 本章已缓存 · GPT-4                              34% · 全书 12%      │
└────────────────────────────────────────────────────────────────────┘
```

- TitleBar 44pt，chrome 色，hairline border。点击 `▢` 切侧栏 (⌘0)，`A- A+` 字号 (⌘+/⌘-)，`⌐` 译文模式循环 (⌘B)，`⚙` 引擎菜单，`☾` 主题，`⋯` 更多菜单。
- Sidebar 240pt，每章一行：罗马数字 + 标题 + 状态 dot：未访问 dot · 翻译中 spinner · 已缓存 / 已读则 ink3 灰。
- 阅读列 padding `56 80 96`（top right/left bottom），内部居中 660pt。
- 章末 prev / next：左灰 + `← 上一章`，右铜色 + `下一章 · Title... →`。
- 底栏 28pt：左 = 本章翻译状态 + 引擎名；右 = 当前章滚动百分比 · 全书百分比。

### 5.2 段落（双语条目）

权威：[design/prototype-parts.jsx:241 PPara](design/prototype-parts.jsx:241)

每段是 `{ en, zh }` 单元，垂直堆叠：

```
[English line]                   ← SERIF, fontSize, color ink, letter-spacing -.003em
( 6pt gap )
[中文译文行]                     ← ZH, ⌈fontSize × 0.83⌉, line-height 1.78, color ink2
( 28pt gap to next pair )
```

ZH 视觉强度三档（[design/prototype-parts.jsx:249](design/prototype-parts.jsx:249) `paraStyle`）：

- **A · 字号 demote**（默认推荐）：纯靠 ink2 + 字号比 en 小约 17% 实现层级；零装饰。
- **B · 左竖线 rule**：12pt 左 padding + 1.5pt rule2 竖线；适合译文很长。
- **C · 淡背景块 tint**：8/12 padding + bgInset 底，radius 4；密度最高，扫读最快，长读易腻。

A/B/C 在 [design/app.jsx:158 Note](design/app.jsx:158) 里被定为"译文视觉强度 1/2/3"的设置项 —— 见 §10 待决问题。

### 5.3 翻译状态机（per chapter & per paragraph）

每章 4 个状态：`idle | translating | cached | error`。详见 [design/prototype.jsx:54](design/prototype.jsx:54) 的 effect。

- 进入未缓存章 → `translating`，按段流式推进（原型用 `setTimeout 380-630ms` 模拟，真实接 SSE）。
- `done` 数字 = 已译段数；段 `idx < done` 渲染译文，`idx ≥ done` 渲染 shimmer skeleton。
- 整章完成 → `cached`；失败 → `error`，按段单独显 `本段翻译失败 · [重试本段]`。
- 后台预取：默认 1 章（[design/prototype-settings.jsx:454 章节预取](design/prototype-settings.jsx:454)），可设 0 / 1 / 2。

### 5.4 划词 → 浮窗（Reader 内）

权威：[design/prototype.jsx:73 handleSelectionMouseUp](design/prototype.jsx:73) + [design/prototype-popups.jsx](design/prototype-popups.jsx)

- mouseup 后 10ms 取 `window.getSelection()`，单词正则 `/^[a-zA-Z'-]+$/` 决定走 word 还是 sentence。
- 4 个 popup kind：
  - `loading` —— skeleton + spinner，模拟 380ms (词) / 720ms (句)。
  - `word` —— IPA + POS 多义项 + `GPT / Claude / DeepSeek` 引擎切换 + 复制 + **+ 生词本**（铜色 primary）。
  - `sentence` —— 原句斜体引文 + hairline + 中文，引擎切换 + speaker + 复制。
  - `error` —— 红铜色标题 "翻译失败" + 中文说明 + mono 错误码 `ETIMEDOUT · api.openai.com:443` + 去设置 + 重试。
- Reader 内浮窗 width 380、radius 12、阴影 `0 24px 60px ...`，clamp 在视口内。

### 5.5 书架视图（Shelf）

权威：[design/prototype-shelf.jsx](design/prototype-shelf.jsx)

- 触发：sidebar 顶部 "◁ 书架" 按钮 → 切到 shelf view（title bar 变 "书架"，右侧 `N 本书 · 返回阅读`）。
- 卡片：168pt 宽，封面 144×216pt，flat 排印（rectangle + title + author + 微 LEXI publisher mark），无 3D。
- 元数据行：标题 / 作者 / 1pt 进度 hairline（已读完用 ink3，否则铜色）/ MONO 行 "NEW / xx% / 已读完  |  最近时间"。
- hover lift `translateY(-3)`，180ms transition。
- 工具栏：搜索框 280pt（`⌘F`），排序段切「最近 / 书名 / 进度」，右上 "+ 添加 EPUB"（铜色 soft）。
- 拖拽 EPUB 任意进窗口 → 全屏 overlay "松开以加入书架"，松开 toast 反馈。
- 右键菜单：打开 ⌘O · 继续阅读 ↵ · Finder 中显示 ⌥⌘R · 清除翻译缓存 (N MB) · 从书架移除 (danger)。
- 分区："继续阅读"（首 3 本）+ "书架"（其余）。

### 5.6 设置面板（Settings Sheet）

权威：[design/prototype-settings.jsx](design/prototype-settings.jsx)

- 触发：`⌘,` 或更多菜单 → 720×580 modal，圆角 10，半透明 backdrop（dark 黑 .55 / light 棕 .30）。
- 假 title bar 有自己的关闭红灯（点 → 关闭 sheet，**注意不是真窗口**）。
- 左 180pt 侧栏 4 tab：通用 · 引擎 · 快捷键 · 阅读器；底部固定 "Lexi 1.0 (build 412) / 检查更新"。
- 控件库：`ITog` 18×32 toggle、`ISelect` 自绘箭头、`ISegmented` 段控、`ISlider` 自绘 16pt 拇指、`IShortcut` mono 键位框、`IButton` (primary / danger / 默认)。

**通用 tab**：
- 启动 Lexi 时：打开上次的书 / 打开书架 / 什么也不做
- 关闭主窗口：**保留在 menu bar**（默认） / 完全退出 ← 关键：Lexi 是 menu-bar 常驻类型
- 缓存路径 `~/Library/Lexi` + 更改
- iCloud 同步进度 + 生词本（默认开）
- 自动检查更新、匿名崩溃日志

**引擎 tab**：
- 默认引擎：段落翻译 + 划词翻译，两个独立 select，options 均为 `OpenAI / Anthropic / DeepSeek`
- API Keys：3 行 OpenAI / Anthropic / DeepSeek，每行 = [● 状态点] + 引擎名 + 副标 + [`SecureField` Key] + [`TextField` Model（带 placeholder）] + [测试]；详见 §0 末尾 "Engine 配置 UI 细节"
- ~~自定义引擎模块~~ — **v1 砍**，整个 section 不渲染
- 翻译缓存：进度条 124/300 MB + 按书清除 · 全部清除 (danger)

**快捷键 tab**：6 个阅读 + 3 个导航 + 冲突检测开关。详见 §7。

**阅读器 tab**：字号 slider 14-22pt · 衬线字体 select · 行距 segmented (紧凑/标准/宽松) · 默认译文模式 · 译文视觉强度 A/B/C · 章节预取 0/1/2 · 主题 · 重音色 swatch picker。

---

## 6. MenuBar 浮窗

[Lexi MenuBar.html](design/Lexi%20MenuBar.html) ⇒ `tweaks-panel + menubar-stage + menubar-popup-v2 + menubar-app`

### 6.1 menu-bar 图标 + 下拉

权威：[design/menubar-stage.jsx:30 MenuBar](design/menubar-stage.jsx:30) + [design/menubar-app.jsx:419 LexiMenu](design/menubar-app.jsx:419)

- Glyph（[`LexiGlyph`](design/menubar-stage.jsx:18)）：两条堆叠水平 bar（原文 + 半透明译文）+ 右上小圆点；抽象，不要画书。
- 激活态（有 popup 显示）→ 图标背景 accentSoft，色铜。
- 点击 → 280pt 下拉面板：
  - Header：`Lexi  ⌘⇧L` + 副 "全局划词翻译已激活"
  - 统计区 2 列：生词本 N 词 · 今日查询 N（SERIF 17pt 大数字）
  - 菜单项：划词翻译 ⌘⇧L · 即时翻译选中文字 ⌘⇧T · 打开阅读器… ⌘⇧K · ─ · 生词本… · **今日复习 (5)**（高亮项，灰显，v1 不接逻辑） · ─ · 设置… ⌘, · 退出 Lexi ⌘Q (danger)

> ⚠️ 原型 [`menubar-app.jsx:458`](design/menubar-app.jsx) 这一行写的是 `⌘⇧R`，与 [`prototype.jsx:241`](design/prototype.jsx) 的"重新翻译本章 ⌘⇧R"冲突。**以本节为准**：menu-bar "打开阅读器" 走 `⌘⇧K`（与全局唤起键一致，本就是同一动作），`⌘⇧R` 留给 Reader 内"重新翻译本章"。

### 6.2 触发方式

权威：[design/menubar-app.jsx:236 onMouseUp](design/menubar-app.jsx:236)

`triggerStyle = 'chip' | 'instant'`：

- **chip**（PopClip 风格）：选区附近先弹一个 32×22 小 chip（Lexi glyph + "译"）；点 chip 才展开 popup。优势：不打扰偶然选区。
- **instant**：选区 mouseup 直接弹 popup。

⌘⇧L 全局快捷键无视 triggerStyle，恒直接弹 popup。

### 6.3 浮窗本体（两个方向）

权威：[design/menubar-popup-v2.jsx](design/menubar-popup-v2.jsx)

| | **A · Minimal** | **B · Power** |
|---|---|---|
| 灵感 | Apple Books look-up | Linear / Raycast |
| 宽 | 320 (word) / 340 (sentence) | 380-420（窗口 < 800 用 380） |
| Word 卡 | IPA + speaker + 最多 2 个义项 + 引擎 pill + + 生词本 | UK / US 双 IPA + 全部义项 + **例句 inset** + **相关词**（斜体 dotted underline）+ 4 个引擎 pill + 发送到 Reader + 生词本 |
| Sentence 卡 | 原句斜体 + hairline + 译文 + 复制 | 同（v1 砍掉了"备选译文 inset"和"发送到 Reader" — 见 §0 决议 10、11） |
| **历史**（仅 B） | — | 顶部 chip 栏 "近期" + 最近 5 词 pill，点击重新查 |
| **Pin**（共用） | header 右 pin/x 按钮；pinned 时忽略 click-outside；标题栏右上角 6pt 铜色 dot 提示 |

Loading / Error 卡 A/B 共用，不分方向。

### 6.4 浮窗定位

`PopFrame` ([design/menubar-popup-v2.jsx:39](design/menubar-popup-v2.jsx:39)) clamp 规则：

- `left = selectionCenterX - W/2`，clamp 在 `[margin, vw - W - margin]`，margin 16
- `top = selectionBottom + 8`；若 `top + 460 > vh - margin` 则翻到选区上方

落到 SwiftUI 时由 panel `setFrame(_:display:)` 实现。

---

## 7. 全部快捷键

| 范畴 | 键位 | 行为 |
|---|---|---|
| **Global** | `⌘⇧L` | 划词翻译（任意 app 选区） |
| **Global** | `⌘⇧T` | 即时翻译选中文字 —— 不弹浮窗，直接替换选区 |
| **Global** | `⌘⇧K` | 显示 / 隐藏阅读器 |
| Reader | `⌘D` | 加入生词本 |
| Reader | `⌘.` | 朗读 |
| Reader | `⌘B` | 切 仅原文 / 译文 / 双语 |
| Reader | `⌘[` `⌘]` | 上 / 下一章 |
| Reader | `⌘0` | 切侧栏 |
| Reader | `⌘+` `⌘-` | 字号 |
| Reader | `⌘,` | 设置 |
| Reader | `⌘⇧R` | 重新翻译本章（更多菜单） |
| 通用 | `Esc` | 关闭浮窗 / 菜单（pinned 浮窗不响应） |
| Shelf | `⌘O` | 打开当前书 |
| Shelf | `↵` | 继续阅读 |
| Shelf | `⌥⌘R` | Finder 中显示 |
| Shelf | `⌘F` | 聚焦搜索框 |

设置里 "冲突检测" toggle 默认开 —— 检测与系统 / 其他 app 冲突时提示。SPM：`sindresorhus/KeyboardShortcuts`。

---

## 8. 翻译引擎模型

**v1 MVP 仅 3 个预设引擎，无本地词典 / 本地 LLM / 自定义引擎**（见 §0 决议 6、7）：

| 引擎 | API host | 默认 model 提示 | 用途 |
|---|---|---|---|
| OpenAI | `api.openai.com` | `gpt-4-turbo` | 段落 + 划词 |
| Anthropic | `api.anthropic.com` | `claude-sonnet-4-6` | 段落 + 划词 |
| DeepSeek | `api.deepseek.com` | `deepseek-chat` | 段落 + 划词 |

> ⚠️ DeepL / Google / Ollama / Llama 3 / 本地 Dict 全部**不在 v1 范围内**。原型里出现这些字样的位置（[`prototype-settings.jsx`](design/prototype-settings.jsx) 的 API Keys section、`customEngines` 数组、`段落引擎 / 划词引擎` select options，以及浮窗 pill）一律改为只显示这 3 家。

每个引擎用户必须自填 **API Key + Model 名**两件事，否则该引擎在 select 里灰显且不可选为默认。

`segmentEngine`（章节流式翻译）和 `popupEngine`（划词浮窗）**独立可选**。引擎切换在以下三处生效：

1. 顶栏 ⚙ 菜单 —— 即时切换本章引擎，不重译已缓存段。
2. 浮窗内 pill —— 当次查询切引擎，重发请求。
3. 设置 / 引擎 tab —— 全局默认。

错误态展示统一格式（[design/menubar-popup-v2.jsx:421 ErrorPopV2](design/menubar-popup-v2.jsx:421)）：标题 "连接 X 超时" + 中文说明 + mono 错误码 + 重试 + 去设置。

---

## 9. 数据模型（初稿）

> Prototype 没写 Swift 实体，下面是从行为推导出的最小模型，留给架构 review 用。

```swift
struct Book {
    let id: String            // 'gatsby'
    var title: String
    var author: String
    var cover: CoverStyle     // bg + ink 两个色（排印封面用）
    var fileURL: URL          // 本地 EPUB 路径
    var progress: Double      // 0...1
    var lastReadAt: Date?
    var addedAt: Date
}

struct Chapter {
    let bookId: String
    let index: Int            // 0-based
    let n: String             // 'III'
    var title: String
    var paragraphs: [Paragraph]
}

struct Paragraph {
    let id: UUID
    let chapterId: ...
    let order: Int
    let en: String
    var translations: [Translation]   // 多引擎结果共存，便于切换
}

struct Translation {
    let engine: EngineID      // .openai / .anthropic / .deepseek
    let model: String         // 翻译时记下用的 model 名，便于 UI 显示来源
    let zh: String
    let createdAt: Date
}

enum ChapterStatus { case idle, translating(done: Int), cached, error(String) }

struct VocabEntry {
    let word: String
    let context: String?      // 句子上下文
    let bookId: String?
    let addedAt: Date
    var srsState: SRSState?   // v2 才用
}

enum EngineID: String, Codable { case openai, anthropic, deepseek }

struct EngineConfig {
    let id: EngineID
    var apiKey: String?       // Keychain 存（Service "com.lexi.engine.<id>")
    var model: String         // 用户填，e.g. "gpt-4-turbo" / "claude-sonnet-4-6" / "deepseek-chat"
    var lastTestedOK: Bool    // 状态点用
}
```

**v1 持久化（全本地，见 §0 决议 4）：**

- **EPUB 文件** → `~/Library/Application Support/Lexi/Books/<id>/`（原始 .epub 拷贝 + 解包后的 chapter cache）
- **业务数据**（books / chapters / paragraphs / translations / vocab / progress）→ 单一 SQLite，建议 [GRDB.swift](https://github.com/groue/GRDB.swift)，文件 `~/Library/Application Support/Lexi/lexi.sqlite`
- **API Key** → Keychain（Service `"com.lexi.engine.<id>"`）
- **UI 偏好** → `@AppStorage` (NSUserDefaults)，**不开 iCloud key-value 同步**

⚠ Xcode 模板生成的 [`lexi/Persistence.swift`](lexi/Persistence.swift)、[`lexi/lexi.xcdatamodeld`](lexi/lexi.xcdatamodeld) 以及 `Item { timestamp }` —— 第一波改造**直接整体删除**（不再保留 Core Data 通道）。`lexiApp.swift` 里的 `persistenceController` 注入也一起拿掉。

---

## 10. SwiftUI 实现交接

每个 surface 的 SwiftUI 实现要点已经在 [design/app.jsx](design/app.jsx) 的 `Note` 卡里写明，原文摘录在下；codex 实现时直接对照：

### 10.1 Tokens → SwiftUI
- Asset Catalog 建 `Lexi/Paper`、`Lexi/Ink`、`Lexi/Ink2`…，开 Any/Dark appearance，自动跟随系统。
- `Color.lexiPaper` / `.lexiInk` / `.lexiInk2` extension。
- 字体：`.font(.custom("NewYork-Regular", size: 17)).lineSpacing(17 * 0.72)`。不要用 `.body / .system`。

### 10.2 Reader · Quiet（默认方向）

> ⚠️ **2026-05-19 修订**：原 hint 是 "fullSizeContentView + 自绘 toolbar"，PR 6 验证下来会跟 macOS 系统 title bar 区视觉打架（双层 header，侧栏 padding 也被推开）。**改用 macOS 原生 toolbar API**：

```swift
WindowGroup("Lexi") {
    NavigationSplitView(columnVisibility: $columnVisibility) {
        TOCSidebar(...)
            .navigationSplitViewColumnWidth(232)
    } detail: {
        ReadingColumn(...)                          // max-width 660pt 居中
    }
    .toolbar {
        ToolbarItem(placement: .navigation) {
            Button { /* toggle sidebar */ } label: {
                Image(systemName: "sidebar.leading")
            }
        }
        ToolbarItem(placement: .principal) {
            // 书名 · 章节 · 进度
        }
        ToolbarItemGroup(placement: .primaryAction) {
            // A- / A+ / 译文模式 / engine / 主题 / 更多
        }
    }
}
.windowStyle(.titleBar)            // 系统标题栏，不要 .hiddenTitleBar
.windowToolbarStyle(.unified)      // toolbar 与 title bar 同行（紧凑布局）
```

**不要**：
- `.windowStyle(.hiddenTitleBar)` — 红绿灯会漂浮在内容上
- `fullSizeContentView` + `titlebarAppearsTransparent` — 双层 header 问题的根源
- 自绘 `HStack { TrafficLights(); ... }` 当作 toolbar

底栏进度 = 1pt Rectangle hairline；字号 `@AppStorage("reader.fontSize")`。

### 10.3 ~~Reader · Composed（已砍，v1 不做）~~
按 §0 决议 1，v1 只做 Quiet 方向，Composed 整段路径不实现。

### 10.4 浮窗 = `NSPanel` (.nonactivatingPanel)
**关键**：浮窗不能抢焦点，否则阅读器选区会丢。

```swift
let panel = NSPanel(
    contentRect: .zero,
    styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
    backing: .buffered, defer: false
)
panel.isFloatingPanel = true
panel.level = .floating
panel.becomesKeyOnlyIfNeeded = true
```

容器用 `NSVisualEffectView .hudWindow + .behindWindow` 实现暖灰玻璃。
点外部消失：`NSEvent.addGlobalMonitor(matching: .leftMouseDown)`。
⌘⇧L 注册：`sindresorhus/KeyboardShortcuts` (SPM)。

### 10.5 书架 = `LazyVGrid` + drop
```swift
LazyVGrid(columns:
  [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 28)],
  spacing: 36
) { ForEach(books) { BookCard($0) } }

// 封面：ZStack(Rectangle + VStack).frame(140, 210).cornerRadius(2)
//       .shadow(color: .black.opacity(0.18), radius: 14, y: 6)

.onDrop(of: [.epub], delegate: ShelfDropDelegate(...))
.contextMenu { ... }
.searchable(text: $query)
```

### 10.6 Settings
**不要** 直接用 `Scene(.settings) { TabView { ... } }` —— macOS 14+ System Settings 已改样，TabView 看起来过时。自己用 `NavigationSplitView` 复刻 prototype。

- API Key 用 `SecureField`（autofill）
- 快捷键录入 `KeyboardShortcuts.Recorder`
- 缓存进度条 `Capsule().frame(width:)` 自绘，不用 `ProgressView`
- 所有 toggle / select 用 `@AppStorage`

---

## 11. 信息架构 (Sitemap)

```
Lexi (单一 .app)
├─ MenuBar Agent              ←  常驻；关闭主窗口默认不退出
│  └─ 280pt dropdown panel
│     ├─ 划词翻译 / 即时翻译 / 打开阅读器
│     ├─ 生词本 / 今日复习
│     └─ 设置 / 退出
│
├─ 全局浮窗 (NSPanel)          ←  ⌘⇧L 或选区 chip 触发
│  ├─ word card (A / B 方向)
│  ├─ sentence card
│  ├─ loading
│  └─ error
│
└─ Reader Window (NSWindow)    ←  Dock 图标 / ⌘⇧K
   ├─ Shelf view
   │  └─ context menu (打开 / Finder / 清缓存 / 移除)
   ├─ Reading view
   │  ├─ Sidebar TOC
   │  ├─ Reading column (660pt)
   │  ├─ Inline popup (word / sentence / loading / error)
   │  ├─ ⚙ Engine menu
   │  └─ ⋯ More menu (重译本章 / 清缓存 / 导出 MD / 生词本 / 设置)
   └─ Settings sheet (modal 720×580)
      └─ 通用 / 引擎 / 快捷键 / 阅读器
```

---

## 12. 决议日志 & 剩余待决

### 已决（2026-05-19）

| # | 决议 | 关联 |
|---|---|---|
| 1 | Reader Quiet + 段落 A + 浮窗 B (Power) 一条路 | §0 / §5.2 / §6.3 |
| 2 | v1 仅 EPUB | §0 |
| 3 | BYOK only，无后端 / 无用户系统 | §0 / §8 |
| 4 | 全本地存储；删 Core Data；上 GRDB；无 CloudKit | §0 / §9 |
| 5 | 生词本 = 收藏 + 列表；SRS 推迟 | §0 |
| 6 | 不内嵌本地词典 / 本地 LLM | §0 / §8 |
| 7 | 引擎只 3 个预设：OpenAI / Anthropic / DeepSeek；每个用户自填 Key + Model；无"自定义引擎"模块 | §0 / §8 |
| 8 | 段落引擎切换不重译已缓存段；只对后续未译段生效 | §0 |
| 9 | EPUB 封面：自带优先，缺失 fallback 排印 | §0 / §5.5 |
| 10 | 浮窗 B 的"备选译文" inset v1 隐藏 | §0 / §6.3 |
| 11 | 浮窗 B 的"发送到 Lexi 阅读器" v1 隐藏 | §0 / §6.3 |
| 12 | 朗读 ⌘. 接 `AVSpeechSynthesizer` | §0 |
| 13 | Model 字段 = `TextField` + placeholder（不写死 enum，不做 picker） | §0 末尾 |
| 14 | "测试"按钮 = 轻量探活：OpenAI/DeepSeek `GET /v1/models` + model 名 grep；Anthropic 用 Haiku 1-token request | §0 末尾 |

### 还没拍的小事

（暂无 — 所有阻塞工程开工的决策都已锁。）

---

## 13. 与 codex 的分工建议

| 我（Claude） | codex |
|---|---|
| 架构 / 数据模型 / 翻译流式协议 | SwiftUI 视图、控件 |
| 设计稿一致性 review | UIKit/AppKit bridge（NSPanel、NSEvent） |
| 引擎抽象接口设计 | 各引擎 client 实现 |
| 待决问题决策推动 | EPUB 解析 / Core Data 迁移 |
| 大型 PR 第二意见（/review、/ultrareview） | 日常实现 PR |

代码风格：codex 走主线，我做架构定义 + 高风险节点二审。

---

**附录 — 文件索引**

| 文件 | 作用 |
|---|---|
| [design/Lexi Prototype.html](design/Lexi%20Prototype.html) | Reader 入口 |
| [design/Lexi MenuBar.html](design/Lexi%20MenuBar.html) | MenuBar 入口 |
| [design/Lexi UI.html](design/Lexi%20UI.html) | 设计画布（含 SwiftUI Note 卡，工程必读） |
| [design/tokens.jsx](design/tokens.jsx) | 颜色 / 字体 / 间距权威定义 |
| [design/reader.jsx](design/reader.jsx) | Reader 静态版（窗口骨架基线） |
| [design/prototype.jsx](design/prototype.jsx) | Reader 交互原型主入口 |
| [design/prototype-parts.jsx](design/prototype-parts.jsx) | Reader 子组件（侧栏 / 顶栏 / 段落 / 阅读列） |
| [design/prototype-popups.jsx](design/prototype-popups.jsx) | Reader 内浮窗 4 态 |
| [design/prototype-shelf.jsx](design/prototype-shelf.jsx) | 书架视图 + 右键菜单 |
| [design/prototype-settings.jsx](design/prototype-settings.jsx) | 设置 sheet 4 tab |
| [design/chapters.jsx](design/chapters.jsx) | 示例数据（Gatsby 9 章 + 10 词字典） |
| [design/menubar-app.jsx](design/menubar-app.jsx) | MenuBar 原型主入口 + LexiMenu 下拉 |
| [design/menubar-popup-v2.jsx](design/menubar-popup-v2.jsx) | A/B 双方向浮窗 |
| [design/menubar-stage.jsx](design/menubar-stage.jsx) | 桌面 + Safari 仿真舞台（含 LexiGlyph） |
| [design/menubar.jsx](design/menubar.jsx) | 浮窗 v1（已被 v2 取代，存档参考） |
| [design/bookshelf.jsx](design/bookshelf.jsx) | 书架 v1（已被 prototype-shelf 取代） |
| [design/settings.jsx](design/settings.jsx) | 设置 v1（已被 prototype-settings 取代） |
| [design/app.jsx](design/app.jsx) | **设计画布根节点 + SwiftUI 实现 Note 卡** ⭐ |
| [design/design-canvas.jsx](design/design-canvas.jsx) | Canvas 框架（开发用，可忽略） |
| [design/tweaks-panel.jsx](design/tweaks-panel.jsx) | Tweaks 面板框架（开发用，可忽略） |
