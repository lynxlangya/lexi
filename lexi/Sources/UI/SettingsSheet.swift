import KeyboardShortcuts
import SwiftUI

struct SettingsSheet: View {
    let database: AppDatabase?
    let close: () -> Void
    let showToast: (String) -> Void

    @State private var selectedTab: SettingsTab = .general
    @State private var apiKeys: [EngineID: String] = [:]
    @State private var loadedAPIKeys: [EngineID: String] = [:]
    @State private var models: [EngineID: String] = Dictionary(
        uniqueKeysWithValues: EngineID.allCases.map { ($0, ReaderFixtureStore.defaultModel(for: $0)) }
    )
    @State private var statuses: [EngineID: EngineStatusDot] = [:]
    @State private var testingEngine: EngineID?
    @State private var cacheBytes: Int64 = 0
    @State private var bookCacheCandidate: String = ""
    @State private var books: [Book] = []
    @State private var localToast: String?

    @AppStorage("general.startup") private var startupBehavior = "last"
    @AppStorage("general.onClose") private var closeBehavior = "menubar"
    @AppStorage("general.autoUpdate") private var autoUpdate = true
    @AppStorage("general.crashLogs") private var crashLogs = true
    @AppStorage("engine.default.chapter") private var defaultChapterEngine = EngineID.deepseek.rawValue
    @AppStorage("engine.default.popup") private var defaultPopupEngine = EngineID.deepseek.rawValue
    @AppStorage("reader.fontSize") private var fontSize = 17.0
    @AppStorage("reader.serif") private var serif = "New York"
    @AppStorage("reader.lineHeight") private var lineHeight = "normal"
    @AppStorage("reader.transMode") private var transMode = ReaderTranslationMode.both.rawValue
    @AppStorage("reader.theme") private var theme = "paper"
    @AppStorage("reader.accent") private var accent = "copper"
    @AppStorage("reader.prefetch") private var prefetch = 1
    @AppStorage("shortcuts.conflictDetect") private var conflictDetect = true

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                titleBar

                NavigationSplitView {
                    sidebar
                } detail: {
                    ScrollView {
                        tabContent
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                    }
                    .background(Color.lexiPaper)
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 180)
                .navigationSplitViewStyle(.balanced)
            }

            SettingsToast(text: localToast)
                .padding(.top, 48)
        }
        .frame(width: 720, height: 580)
        .background(Color.lexiPaper)
        .clipShape(RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous)
                .stroke(Color.lexiRule, lineWidth: 1)
        }
        .task {
            await loadValues()
        }
        .onChange(of: defaultChapterEngine) { _, _ in
            NotificationCenter.default.post(name: .lexiChapterEngineSettingsChanged, object: nil)
        }
        .onChange(of: defaultPopupEngine) { _, _ in
            NotificationCenter.default.post(name: .lexiPopupEngineSettingsChanged, object: nil)
        }
        .onDisappear {
            saveAPIKeys()
        }
    }

    private var titleBar: some View {
        ZStack {
            HStack(spacing: 8) {
                Button(action: close) {
                    Circle()
                        .fill(Color(red: 1, green: 0.37, blue: 0.34))
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .help("关闭")

                Circle()
                    .fill(Color(red: 1, green: 0.74, blue: 0.18))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                    .frame(width: 12, height: 12)

                Spacer()
            }
            .padding(.horizontal, 12)

            Text("设置")
                .font(LexiFont.zh(12))
                .fontWeight(.medium)
                .foregroundStyle(Color.lexiInk2)
        }
        .frame(height: 38)
        .background(Color.lexiChrome)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lexiRule).frame(height: 1)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 16)
                        Text(tab.title)
                            .font(LexiFont.zh(13))
                        Spacer()
                    }
                    .foregroundStyle(selectedTab == tab ? Color.lexiAccent : Color.lexiInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(selectedTab == tab ? Color.lexiAccentSoft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Lexi 1.0 (build 412)")
                Text("检查更新…")
                    .foregroundStyle(Color.lexiAccent)
            }
            .font(LexiFont.sans(10.5))
            .foregroundStyle(Color.lexiInk3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.lexiRule).frame(height: 1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color.lexiRaised)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .general:
            generalTab
        case .engine:
            engineTab
        case .shortcuts:
            shortcutsTab
        case .reader:
            readerTab
        }
    }

    private var generalTab: some View {
        VStack(spacing: 0) {
            SettingsSection(title: "启动 / 退出") {
                SettingsRow(label: "启动 Lexi 时") {
                    SettingsSelect(
                        value: $startupBehavior,
                        options: [
                            ("last", "打开上次的书"),
                            ("shelf", "打开书架"),
                            ("none", "什么也不做"),
                        ]
                    )
                }
                SettingsRow(
                    label: "关闭主窗口",
                    hint: "保留 menu-bar 浮窗与全局划词翻译",
                    isLast: true
                ) {
                    SettingsSelect(
                        value: $closeBehavior,
                        options: [
                            ("menubar", "保留在 menu bar"),
                            ("quit", "完全退出"),
                        ]
                    )
                }
            }

            SettingsSection(title: "数据") {
                SettingsRow(label: "书籍与翻译缓存位置", isLast: true) {
                    HStack(spacing: 8) {
                        Text("~/Library/Application Support/Lexi")
                            .font(LexiFont.mono(11))
                            .foregroundStyle(Color.lexiInk3)
                        Button("更改…") {
                            toast("v1 暂不支持更改缓存路径")
                        }
                        .font(LexiFont.zh(11.5))
                    }
                }
            }

            SettingsSection(title: "关于") {
                SettingsRow(label: "自动检查更新") {
                    Toggle("", isOn: $autoUpdate)
                        .labelsHidden()
                }
                SettingsRow(label: "发送匿名崩溃日志", isLast: true) {
                    Toggle("", isOn: $crashLogs)
                        .labelsHidden()
                }
            }
        }
    }

    private var engineTab: some View {
        VStack(spacing: 0) {
            SettingsSection(title: "默认引擎") {
                SettingsRow(
                    label: "段落翻译",
                    hint: "阅读章节时整页 / 整段翻译"
                ) {
                    SettingsSelect(value: $defaultChapterEngine, options: engineOptions)
                }
                SettingsRow(
                    label: "划词翻译",
                    hint: "选中文字 / ⌘⇧L 浮窗弹出",
                    isLast: true
                ) {
                    SettingsSelect(value: $defaultPopupEngine, options: engineOptions)
                }
            }

            SettingsSection(title: "API Keys") {
                ForEach(Array(EngineID.allCases.enumerated()), id: \.element) { index, engine in
                    EngineRow(
                        engine: engine,
                        subtitle: subtitle(for: engine),
                        status: statuses[engine] ?? (apiKeys[engine, default: ""].isEmpty ? .unset : .ok),
                        apiKey: binding(for: engine, in: $apiKeys),
                        model: binding(for: engine, in: $models),
                        testing: testingEngine == engine
                    ) {
                        test(engine)
                    }
                    .overlay(alignment: .bottom) {
                        if index < EngineID.allCases.count - 1 {
                            Rectangle().fill(Color.lexiRule).frame(height: 1)
                        }
                    }
                }
            }

            SettingsSection(title: "翻译缓存") {
                SettingsRow(label: "总占用") {
                    VStack(alignment: .trailing, spacing: 4) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.lexiRule)
                                .frame(width: 200, height: 4)
                            Capsule()
                                .fill(Color.lexiAccent)
                                .frame(width: min(200, CGFloat(cacheBytesMB / 300) * 200), height: 4)
                        }
                        Text("\(Int(cacheBytesMB.rounded())) / 300 MB")
                            .font(LexiFont.mono(10))
                            .foregroundStyle(Color.lexiInk3)
                    }
                }
                SettingsRow(label: "", isLast: true) {
                    HStack(spacing: 8) {
                        Picker("按书清除", selection: $bookCacheCandidate) {
                            Text("选择书籍").tag("")
                            ForEach(books) { book in
                                Text(book.title).tag(book.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)

                        Button("清除") {
                            clearSelectedBookCache()
                        }
                        .font(LexiFont.zh(11.5))
                        .disabled(bookCacheCandidate.isEmpty)

                        Button("全部清除", role: .destructive) {
                            clearAllCache()
                        }
                        .font(LexiFont.zh(11.5))
                    }
                }
            }
        }
    }

    private var shortcutsTab: some View {
        VStack(spacing: 0) {
            SettingsSection(title: "阅读器") {
                ShortcutRecorder(title: "切换 仅原文/译文/双语", name: .readerToggleTranslationMode)
                    .settingsShortcutRow(last: false)
                ShortcutRecorder(title: "上一章", name: .readerPreviousChapter)
                    .settingsShortcutRow(last: false)
                ShortcutRecorder(title: "下一章", name: .readerNextChapter)
                    .settingsShortcutRow(last: false)
                ShortcutRecorder(title: "增大字号", name: .readerIncreaseFontSize)
                    .settingsShortcutRow(last: false)
                ShortcutRecorder(title: "减小字号", name: .readerDecreaseFontSize)
                    .settingsShortcutRow(last: false)
                ShortcutRecorder(title: "切换侧栏目录", name: .readerToggleSidebar)
                    .settingsShortcutRow(last: true)
            }

            SettingsSection(title: "导航") {
                ShortcutRecorder(title: "划词翻译", name: .translateSelection)
                    .settingsShortcutRow(last: false)
                ShortcutRecorder(title: "即时翻译选中文字", name: .translateAndReplaceSelection)
                    .settingsShortcutRow(last: false)
                ShortcutRecorder(title: "显示 / 隐藏阅读器", name: .toggleReaderWindow)
                    .settingsShortcutRow(last: true)
            }

            SettingsSection(title: "") {
                SettingsRow(label: "冲突检测", hint: "当 Lexi 快捷键与系统或其他 app 冲突时提示", isLast: true) {
                    Toggle("", isOn: $conflictDetect)
                        .labelsHidden()
                }
            }
        }
    }

    private var readerTab: some View {
        VStack(spacing: 0) {
            SettingsSection(title: "排版") {
                SettingsRow(label: "正文字号", hint: "也可在阅读时用 ⌘+ / ⌘- 临时调整") {
                    HStack(spacing: 10) {
                        Text("\(Int(fontSize))pt")
                            .font(LexiFont.mono(11))
                            .foregroundStyle(Color.lexiInk3)
                            .frame(width: 42, alignment: .trailing)
                        Slider(value: $fontSize, in: 14...22, step: 1)
                            .frame(width: 200)
                    }
                }
                SettingsRow(label: "衬线字体") {
                    SettingsSelect(
                        value: $serif,
                        options: [
                            ("New York", "New York"),
                            ("Charter", "Charter"),
                            ("Iowan Old Style", "Iowan Old Style"),
                            ("Georgia", "Georgia"),
                        ]
                    )
                }
                SettingsRow(label: "行距", hint: "影响 EN 正文，ZH 自动 +6%", isLast: true) {
                    SettingsSegmented(
                        value: $lineHeight,
                        options: [
                            ("tight", "紧凑"),
                            ("normal", "标准"),
                            ("loose", "宽松"),
                        ]
                    )
                }
            }

            SettingsSection(title: "译文显示") {
                SettingsRow(label: "默认显示模式") {
                    SettingsSegmented(
                        value: $transMode,
                        options: [
                            ("both", "原文+译文"),
                            ("en", "仅原文"),
                            ("zh", "仅译文"),
                        ]
                    )
                }
                SettingsRow(label: "章节预取", hint: "后台预先翻译相邻章节", isLast: true) {
                    Picker("", selection: $prefetch) {
                        Text("0").tag(0)
                        Text("1 章").tag(1)
                        Text("2 章").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 150)
                }
            }

            SettingsSection(title: "主题") {
                SettingsRow(label: "模式") {
                    SettingsSegmented(
                        value: $theme,
                        options: [
                            ("paper", "亮 Paper"),
                            ("candlelit", "暗 Candlelit"),
                        ]
                    )
                }
                SettingsRow(label: "重音色", isLast: true) {
                    HStack(spacing: 8) {
                        ForEach(accentOptions, id: \.0) { option in
                            Button {
                                accent = option.0
                            } label: {
                                Circle()
                                    .fill(option.1)
                                    .frame(width: 22, height: 22)
                                    .overlay {
                                        Circle()
                                            .stroke(accent == option.0 ? Color.lexiInk : Color.clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var engineOptions: [(String, String)] {
        EngineID.allCases.map { ($0.rawValue, $0.displayName) }
    }

    private var accentOptions: [(String, Color)] {
        [
            ("copper", .lexiAccent),
            ("moss", Color(red: 0.36, green: 0.52, blue: 0.36)),
            ("plum", Color(red: 0.46, green: 0.38, blue: 0.56)),
            ("ink", .lexiInk2),
        ]
    }

    private var cacheBytesMB: Double {
        Double(cacheBytes) / 1024 / 1024
    }

    private func subtitle(for engine: EngineID) -> String {
        switch engine {
        case .openai:
            return "Chat Completions"
        case .anthropic:
            return "Messages API"
        case .deepseek:
            return "OpenAI-compatible"
        }
    }

    private func loadValues() async {
        var nextKeys: [EngineID: String] = [:]
        var nextModels = models
        var nextStatuses = statuses

        for engine in EngineID.allCases {
            let key = Keychain.apiKey(for: engine) ?? ""
            nextKeys[engine] = key
            if let config = try? await database?.engineConfig(for: engine) {
                nextModels[engine] = config.model
                nextStatuses[engine] = config.lastTestedOK ? .ok : (key.isEmpty ? .unset : .fail)
            } else if !key.isEmpty {
                nextStatuses[engine] = .ok
            }
        }

        apiKeys = nextKeys
        loadedAPIKeys = nextKeys
        models = nextModels
        statuses = nextStatuses
        cacheBytes = (try? await database?.translationCacheBytes()) ?? 0
        books = (try? await database?.books()) ?? []
    }

    private func test(_ engine: EngineID) {
        guard let key = apiKeys[engine], !key.isEmpty else {
            statuses[engine] = .unset
            Keychain.delete(engine)
            toast("请先填写 \(engine.displayName) API Key")
            return
        }

        let model = models[engine, default: ReaderFixtureStore.defaultModel(for: engine)]
        saveAPIKeys(notify: false)
        testingEngine = engine

        Task {
            do {
                let config = EngineConfig(id: engine, model: model, lastTestedOK: false, lastTestedAt: nil)
                let result = try await EngineRegistry.shared.engine(for: config).ping(model: model)
                let now = Date()
                switch result {
                case .ok:
                    statuses[engine] = .ok
                    try? await database?.upsertEngineConfig(EngineConfig(id: engine, model: model, lastTestedOK: true, lastTestedAt: now))
                    NotificationCenter.default.post(name: .lexiEngineSettingsChanged, object: nil)
                    toast("\(engine.displayName) 连接成功")
                case .keyOkModelUnknown:
                    statuses[engine] = .keyOkModelUnknown
                    try? await database?.upsertEngineConfig(EngineConfig(id: engine, model: model, lastTestedOK: false, lastTestedAt: now))
                    NotificationCenter.default.post(name: .lexiEngineSettingsChanged, object: nil)
                    toast("Key 可用，模型名未确认")
                case .fail(let reason):
                    statuses[engine] = .fail
                    try? await database?.upsertEngineConfig(EngineConfig(id: engine, model: model, lastTestedOK: false, lastTestedAt: now))
                    NotificationCenter.default.post(name: .lexiEngineSettingsChanged, object: nil)
                    toast(reason)
                }
            } catch {
                statuses[engine] = .fail
                toast(error.localizedDescription)
            }
            testingEngine = nil
        }
    }

    private func saveAPIKeys(notify: Bool = true) {
        var changed = false
        for engine in EngineID.allCases {
            let key = apiKeys[engine, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            if loadedAPIKeys[engine, default: ""] != key {
                changed = true
            }
            if key.isEmpty {
                Keychain.delete(engine)
            } else {
                Keychain.setApiKey(key, for: engine)
            }
            loadedAPIKeys[engine] = key
        }
        if notify, changed {
            notifyEngineSettingsChanged()
        }
    }

    private func notifyEngineSettingsChanged() {
        NotificationCenter.default.post(name: .lexiEngineSettingsChanged, object: nil)
    }

    private func clearSelectedBookCache() {
        guard !bookCacheCandidate.isEmpty else {
            return
        }
        Task {
            try? await database?.clearTranslationCache(bookId: bookCacheCandidate)
            cacheBytes = (try? await database?.translationCacheBytes()) ?? 0
            toast("已清除该书缓存")
        }
    }

    private func clearAllCache() {
        Task {
            try? await database?.clearTranslationCache()
            cacheBytes = 0
            toast("已清除全部翻译缓存")
        }
    }

    private func toast(_ text: String) {
        withAnimation(.easeOut(duration: 0.16)) {
            localToast = text
        }
        showToast(text)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeIn(duration: 0.16)) {
                if localToast == text {
                    localToast = nil
                }
            }
        }
    }

    private func binding(
        for engine: EngineID,
        in dictionary: Binding<[EngineID: String]>
    ) -> Binding<String> {
        Binding {
            dictionary.wrappedValue[engine, default: ""]
        } set: { value in
            dictionary.wrappedValue[engine] = value
        }
    }
}

private extension View {
    func settingsShortcutRow(last: Bool) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                if !last {
                    Rectangle()
                        .fill(Color.lexiRule)
                        .frame(height: 1)
                }
            }
    }
}
