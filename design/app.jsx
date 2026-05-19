// app.jsx — Lexi design canvas
// Composes all sections: Foundations, Reader (Quiet + Composed),
// 段落译文 styles, 划词浮窗, plus inline SwiftUI hints.

const { useState } = React;

// height-flexible wrapper so the popups (which are variable height) fit
// neatly in fixed-height artboards.
function PopWrap({ children, h }) {
  return (
    <div style={{
      width:'100%', height: h, display:'flex',
      alignItems:'center', justifyContent:'center',
      padding: 18, boxSizing:'border-box',
    }}>{children}</div>
  );
}

// A small inline annotation card — used as a "SwiftUI hint" or design note.
function Note({ title, body, kind = 'swift' }) {
  return (
    <div style={{
      background:'#fbf9f3', color:'#3a3328',
      border:'1px solid #e3dccb',
      borderRadius: 8, padding:'14px 16px',
      width:'100%', height:'100%', boxSizing:'border-box',
      fontFamily: SANS, display:'flex', flexDirection:'column', gap: 8,
    }}>
      <div style={{
        fontFamily: MONO, fontSize: 10, letterSpacing:'.1em',
        color: kind === 'swift' ? '#9c4a39' : '#7a7163',
        textTransform:'uppercase', fontWeight: 600,
      }}>{kind === 'swift' ? 'SwiftUI · 实现提示' : 'Note'}</div>
      <div style={{fontSize: 13, fontWeight: 600, letterSpacing:'-.005em'}}>{title}</div>
      <div style={{fontSize: 12, lineHeight: 1.55, color:'#5a5246', whiteSpace:'pre-line'}}>{body}</div>
    </div>
  );
}

function App() {
  return (
    <DesignCanvas>
      {/* ─────────── FOUNDATIONS ─────────── */}
      <DCSection id="foundations" title="Foundations · 设计基底" subtitle="暖色双模 · 仅一处铜色重音 · 极少层级">
        <DCArtboard id="pal-light" label="Palette · Light" width={440} height={620}>
          <PalettePanel mode="light" />
        </DCArtboard>
        <DCArtboard id="pal-dark"  label="Palette · Dark"  width={440} height={620}>
          <PalettePanel mode="dark"  />
        </DCArtboard>
        <DCArtboard id="type-light" label="Type · Light" width={540} height={620}>
          <TypeSpecimen mode="light" />
        </DCArtboard>
        <DCArtboard id="type-dark"  label="Type · Dark"  width={540} height={620}>
          <TypeSpecimen mode="dark"  />
        </DCArtboard>
        <DCArtboard id="rhythm-light" label="Rhythm · Light" width={520} height={620}>
          <SpacingCard mode="light" />
        </DCArtboard>
        <DCArtboard id="rhythm-dark"  label="Rhythm · Dark"  width={520} height={620}>
          <SpacingCard mode="dark"  />
        </DCArtboard>
        <DCArtboard id="found-note" label="Tokens · 实现提示" width={440} height={620}>
          <Note
            title="把 token 直接落到 SwiftUI"
            body={`Color extension：
  Color.lexiPaper     // 亮 #f5f1e8 / 暗 #1c1915
  Color.lexiInk       // primary
  Color.lexiInk2      // 译文（zh）

Asset Catalog 里建 "Lexi/Paper" 等 named colors，开两套 appearance（Any / Dark），系统 dark-mode 自动切换。

字体：
  .font(.custom("NewYork-Regular", size: 17))
  .lineSpacing(17 * 0.72)   // 行高 1.72

不要用 .body / .system —— iOS-Books 的版面靠的是手工字号 + 行距。`}
          />
        </DCArtboard>
      </DCSection>

      {/* ─────────── READER · QUIET ─────────── */}
      <DCSection id="reader-quiet" title="A. 阅读器 · Quiet 方向"
        subtitle="保守路线：参考 Apple Books / Mail · 侧栏目录可见 · 顶栏明确但克制">
        <DCArtboard id="quiet-light" label="Light · idle" width={1200} height={760}>
          <ReaderWindow theme="light" direction="quiet" state="idle" />
        </DCArtboard>
        <DCArtboard id="quiet-dark" label="Dark · idle" width={1200} height={760}>
          <ReaderWindow theme="dark" direction="quiet" state="idle" />
        </DCArtboard>
        <DCArtboard id="quiet-dark-translating" label="Dark · 翻译中" width={1200} height={760}>
          <ReaderWindow theme="dark" direction="quiet" state="translating" />
        </DCArtboard>
        <DCArtboard id="quiet-light-error" label="Light · 单段错误态" width={1200} height={760}>
          <ReaderWindow theme="light" direction="quiet" state="error" />
        </DCArtboard>
        <DCArtboard id="quiet-note" label="SwiftUI · Quiet" width={440} height={760}>
          <Note
            title="窗口骨架"
            body={`NSWindow with .titled, .fullSizeContentView, .titlebarAppearsTransparent，把 toolbar 自己画到 contentView 顶部。

NavigationSplitView 是免费的：
  NavigationSplitView {
    TOCSidebar()           // 232pt 宽，.listStyle(.sidebar)
  } detail: {
    ReadingColumn()        // 自己控宽，max-width 660pt 居中
  }

底栏进度条 = 1pt Rectangle，hairline 即可。

字号按钮：维护 @AppStorage("reader.fontSize")，body view 用 .font(.custom("NewYork-Regular", size: size))。`}
          />
        </DCArtboard>
      </DCSection>

      {/* ─────────── READER · COMPOSED ─────────── */}
      <DCSection id="reader-composed" title="B. 阅读器 · Composed 方向"
        subtitle="大胆路线：参考 iA Writer · 几乎无 chrome · 大留白 · 章节标题用斜体 New York">
        <DCArtboard id="composed-light" label="Light · idle" width={1200} height={760}>
          <ReaderWindow theme="light" direction="composed" state="idle" showSidebar={false} />
        </DCArtboard>
        <DCArtboard id="composed-dark" label="Dark · idle" width={1200} height={760}>
          <ReaderWindow theme="dark" direction="composed" state="idle" showSidebar={false} />
        </DCArtboard>
        <DCArtboard id="composed-dark-trans" label="Dark · 翻译流式中" width={1200} height={760}>
          <ReaderWindow theme="dark" direction="composed" state="translating" showSidebar={false} />
        </DCArtboard>
        <DCArtboard id="composed-dark-sel" label="Dark · 划词选中" width={1200} height={760}>
          <ReaderWindow theme="dark" direction="composed" state="idle" selectedIdx={1} showSidebar={false} />
        </DCArtboard>
        <DCArtboard id="composed-note" label="SwiftUI · Composed" width={440} height={760}>
          <Note
            title="把 chrome 真的藏起来"
            body={`目标：进入阅读后 1.5s 没有鼠标移动，顶栏淡出到 alpha 0；任何鼠标移动都立刻 fade in (.easeOut 200ms)。

  @State var chromeVisible = true
  let idleTimer = …  // Combine timer
  .onContinuousHover { _ in chromeVisible = true; resetTimer() }
  .opacity(chromeVisible ? 1 : 0)
  .animation(.easeOut(duration: 0.2), value: chromeVisible)

红绿灯 fade 时也要带走，不然空浮着很丑：
  .windowToolbarVisibility(.automatic)
  或在 fullSizeContentView 模式下自己控制 standardWindowButton(...).isHidden`}
          />
        </DCArtboard>
      </DCSection>

      {/* ─────────── PARAGRAPH TRANSLATION STYLES ─────────── */}
      <DCSection id="para-styles" title="段落译文 · 三种处理方式"
        subtitle="用同一段 Gatsby 文本横向对比 · 选定后用在阅读器主窗口">
        <DCArtboard id="para-light" label="Light · A / B / C" width={1280} height={460}>
          <ParaStyleCompare theme="light" />
        </DCArtboard>
        <DCArtboard id="para-dark"  label="Dark · A / B / C"  width={1280} height={460}>
          <ParaStyleCompare theme="dark"  />
        </DCArtboard>
        <DCArtboard id="para-note" label="推荐 / 取舍" width={440} height={460}>
          <Note kind="note"
            title="个人推荐：A · TYPOGRAPHY"
            body={`A 最贴合"译文是辅助不是主角"：
  · 视觉密度最低，1-2 小时阅读疲劳最轻
  · 段间距明显 > 段内（en+zh）距，鼻子能闻出节奏
  · 关键是 ink2 颜色：比 ink 淡 28-32%，正好"看得清但不抢眼"

B（细竖线）适合译文较长的场景，或将来加"译文折叠/展开"。

C（淡背景）扫读最快，但密度高，长时段易腻；当作"译文为主"模式的备选。

可以做成 Tweaks：阅读器设置里"译文视觉强度" 1/2/3。`}
          />
        </DCArtboard>
      </DCSection>

      {/* ─────────── MENU-BAR POPUP ─────────── */}
      <DCSection id="popup" title="C. 划词浮窗 · 4 状态"
        subtitle="跟随鼠标 · 与阅读器同一套字体/圆角/暗色配色 · 1px 描边模拟系统 vibrancy">

        <DCArtboard id="word-light" label="Word · Light" width={420} height={480}>
          <PopWrap h={480}><WordPop theme="light" /></PopWrap>
        </DCArtboard>
        <DCArtboard id="sent-light" label="Sentence · Light" width={420} height={480}>
          <PopWrap h={480}><SentencePop theme="light" /></PopWrap>
        </DCArtboard>
        <DCArtboard id="load-light" label="Loading · Light" width={420} height={480}>
          <PopWrap h={480}><LoadingPop theme="light" /></PopWrap>
        </DCArtboard>
        <DCArtboard id="err-light"  label="Error · Light"   width={420} height={480}>
          <PopWrap h={480}><ErrorPop theme="light" /></PopWrap>
        </DCArtboard>

        <DCArtboard id="word-dark" label="Word · Dark" width={420} height={480}>
          <PopWrap h={480}><WordPop theme="dark" /></PopWrap>
        </DCArtboard>
        <DCArtboard id="sent-dark" label="Sentence · Dark" width={420} height={480}>
          <PopWrap h={480}><SentencePop theme="dark" /></PopWrap>
        </DCArtboard>
        <DCArtboard id="load-dark" label="Loading · Dark" width={420} height={480}>
          <PopWrap h={480}><LoadingPop theme="dark" /></PopWrap>
        </DCArtboard>
        <DCArtboard id="err-dark"  label="Error · Dark"   width={420} height={480}>
          <PopWrap h={480}><ErrorPop theme="dark" /></PopWrap>
        </DCArtboard>

        <DCArtboard id="popup-note" label="SwiftUI · 浮窗" width={440} height={480}>
          <Note
            title="浮窗 = NSPanel · .nonactivatingPanel"
            body={`关键：浮窗不能抢焦点，否则阅读器选区会丢。

  let panel = NSPanel(
    contentRect: .zero,
    styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
    backing: .buffered, defer: false
  )
  panel.isFloatingPanel = true
  panel.level = .floating
  panel.becomesKeyOnlyIfNeeded = true

容器用 NSVisualEffectView .hudWindow + .behindWindow 实现暖灰玻璃。

鼠标点外部消失：NSEvent.addGlobalMonitor(matching: .leftMouseDown)，命中区外即 close()。

⌘⇧L 注册：MASShortcut / KeyboardShortcuts (SPM)。`}
          />
        </DCArtboard>
      </DCSection>

      {/* ─────────── FLOW NOTE ─────────── */}
      <DCSection id="flow" title="核心交互流程" subtitle="一句话讲清 Lexi 的使用闭环">
        <DCArtboard id="flow-card" label="Open → Read → Lookup" width={1280} height={300}>
          <FlowDiagram />
        </DCArtboard>
      </DCSection>

      {/* ─────────── BOOKSHELF / OPEN PAGE ─────────── */}
      <DCSection id="bookshelf" title="B. 书架 / 打开页"
        subtitle="启动默认页 · 极简卡片网格 · 封面用排印代替写实">
        <DCArtboard id="bk-light" label="Light · 默认" width={1100} height={760}>
          <BookshelfWindow theme="light" state="default" />
        </DCArtboard>
        <DCArtboard id="bk-dark" label="Dark · 默认" width={1100} height={760}>
          <BookshelfWindow theme="dark" state="default" />
        </DCArtboard>
        <DCArtboard id="bk-empty" label="Light · 空状态" width={1100} height={760}>
          <BookshelfWindow theme="light" state="empty" />
        </DCArtboard>
        <DCArtboard id="bk-drag" label="Light · 拖拽中" width={1100} height={760}>
          <BookshelfWindow theme="light" state="drag" />
        </DCArtboard>
        <DCArtboard id="bk-search" label="Dark · 搜索" width={1100} height={760}>
          <BookshelfWindow theme="dark" state="search" />
        </DCArtboard>
        <DCArtboard id="bk-ctx-light" label="右键菜单 · Light" width={260} height={420}>
          <div style={{padding: 24, display:'flex', alignItems:'center', justifyContent:'center', height:'100%'}}>
            <BookContextMenu t={TOKENS.light} theme="light" />
          </div>
        </DCArtboard>
        <DCArtboard id="bk-ctx-dark" label="右键菜单 · Dark" width={260} height={420}>
          <div style={{padding: 24, display:'flex', alignItems:'center', justifyContent:'center', height:'100%', background:'#1c1915'}}>
            <BookContextMenu t={TOKENS.dark} theme="dark" />
          </div>
        </DCArtboard>
        <DCArtboard id="bk-note" label="SwiftUI · 书架" width={440} height={760}>
          <Note
            title="书架 ≈ LazyVGrid + 拖拽落点"
            body={`卡片网格：
  LazyVGrid(columns:
    [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 28)],
    spacing: 36
  ) { ForEach(books) { BookCard($0) } }

封面 = 矩形 + 类型 (无 3D)：
  ZStack(alignment: .topLeading) {
    Rectangle().fill(book.coverColor)
    VStack(alignment: .leading) { ... }
  }.frame(width: 140, height: 210).cornerRadius(2)
   .shadow(color: .black.opacity(0.18), radius: 14, y: 6)

拖拽接收：
  .onDrop(of: [.epub], delegate: ShelfDropDelegate(...))
  → 命中后改 dragOverlay = true，松手 → 入库 + auto open

右键菜单：
  .contextMenu { ... } — SwiftUI 原生即可

排序/搜索框：NSSearchToolbarItem + UIKit-bridge 或 .searchable()`}
          />
        </DCArtboard>
      </DCSection>

      {/* ─────────── SETTINGS PANEL ─────────── */}
      <DCSection id="settings" title="D. 设置面板"
        subtitle="四栏：通用 · 引擎 · 快捷键 · 阅读器 · macOS 14+ System Settings 风格">
        <DCArtboard id="set-dark-general"  label="Dark · 通用"   width={720} height={580}>
          <SettingsWindow theme="dark" tab="general" />
        </DCArtboard>
        <DCArtboard id="set-dark-engine"   label="Dark · 引擎"   width={720} height={580}>
          <SettingsWindow theme="dark" tab="engine" />
        </DCArtboard>
        <DCArtboard id="set-dark-shortcut" label="Dark · 快捷键" width={720} height={580}>
          <SettingsWindow theme="dark" tab="shortcut" />
        </DCArtboard>
        <DCArtboard id="set-dark-reader"   label="Dark · 阅读器" width={720} height={580}>
          <SettingsWindow theme="dark" tab="reader" />
        </DCArtboard>
        <DCArtboard id="set-light-general" label="Light · 通用"  width={720} height={580}>
          <SettingsWindow theme="light" tab="general" />
        </DCArtboard>
        <DCArtboard id="set-light-engine"  label="Light · 引擎"  width={720} height={580}>
          <SettingsWindow theme="light" tab="engine" />
        </DCArtboard>
        <DCArtboard id="set-light-reader"  label="Light · 阅读器" width={720} height={580}>
          <SettingsWindow theme="light" tab="reader" />
        </DCArtboard>
        <DCArtboard id="set-note" label="SwiftUI · 设置" width={440} height={580}>
          <Note
            title="Settings = Scene(.settings)"
            body={`SwiftUI 原生设置场景：
  Settings {
    TabView {
      GeneralView().tabItem { ... }
      EngineView().tabItem { ... }
      ShortcutsView().tabItem { ... }
      ReaderView().tabItem { ... }
    }
  }

但是 — macOS 14 之后 System Settings 改了，TabView 看起来过时。
更现代的做法：自己用 NavigationSplitView 复刻，
就像设计稿里这样。

API Key 字段：
  SecureField — 自动密码格式 + autofill

快捷键录入：
  KeyboardShortcuts.Name + KeyboardShortcuts.Recorder
  (sindresorhus/KeyboardShortcuts SPM)

缓存进度条：自定义 Capsule().frame(width:)，
不要用 ProgressView — 它的样式跟整个 app 不一致。

@AppStorage 持久化所有 toggle / select。`}
          />
        </DCArtboard>
      </DCSection>

    </DesignCanvas>
  );
}

// ─────────── flow diagram (inline SVG-ish via divs) ───────────

function FlowDiagram() {
  const t = TOKENS.light;
  const steps = [
    { k: '01', label: '打开 EPUB',  body: '拖拽 / ⌘O\n书架记录' },
    { k: '02', label: '预取章节',   body: '当前 + 下一章\n并行翻译' },
    { k: '03', label: '阅读',       body: '原文为主\n译文 80% 时间在视野边缘' },
    { k: '04', label: '划词',       body: '⌘⇧L\n浮窗跟随鼠标' },
    { k: '05', label: '加生词',     body: '点 + 收入\nv2: 复习卡' },
    { k: '06', label: '切章',       body: '侧栏 / 翻页\n预取下一章' },
  ];
  return (
    <div style={{
      background: t.bg, height:'100%', padding:'40px 36px',
      border:`1px solid ${t.rule}`, borderRadius: 8,
      display:'flex', alignItems:'center', gap: 0, boxSizing:'border-box',
      fontFamily: SANS,
    }}>
      {steps.map((s, i) => (
        <React.Fragment key={s.k}>
          <div style={{flex:'1 1 0', minWidth: 0, paddingRight: 8}}>
            <div style={{fontFamily: MONO, fontSize: 11, color: t.accent, letterSpacing:'.08em', fontWeight: 600}}>{s.k}</div>
            <div style={{height: 6}} />
            <div style={{fontFamily: SERIF, fontSize: 17, color: t.ink, letterSpacing:'-.005em'}}>{s.label}</div>
            <div style={{height: 6}} />
            <div style={{fontSize: 11.5, color: t.ink2, lineHeight: 1.55, whiteSpace:'pre-line'}}>{s.body}</div>
          </div>
          {i < steps.length - 1 && (
            <div style={{
              flex:'0 0 auto', width: 20, color: t.ink3,
              fontFamily: SERIF, fontSize: 20, textAlign:'center',
            }}>→</div>
          )}
        </React.Fragment>
      ))}
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
