import KeyboardShortcuts
import SwiftUI

struct SettingsKeychainSaveResult<Key: Hashable> {
    var changed: Bool
    var savedValues: [Key: String]
}

struct SettingsTTSKeySaveResult {
    var changed: Bool
    var savedKey: String
}

enum SettingsKeychainSaveError: Error, Equatable {
    case engine(EngineID)
    case tts(TTSProviderID)
}

struct SettingsKeychainPersistence {
    var setEngineAPIKey: (String, EngineID) throws -> Void
    var deleteEngineAPIKey: (EngineID) throws -> Void
    var setTTSAPIKey: (String, TTSProviderID) throws -> Void
    var deleteTTSAPIKey: (TTSProviderID) throws -> Void

    static let live = SettingsKeychainPersistence(
        setEngineAPIKey: Keychain.setApiKeyThrowing,
        deleteEngineAPIKey: Keychain.deleteThrowing,
        setTTSAPIKey: TTSKeychain.setApiKeyThrowing,
        deleteTTSAPIKey: TTSKeychain.deleteThrowing
    )

    func saveEngineAPIKeys(
        apiKeys: [EngineID: String],
        loadedKeys: [EngineID: String]
    ) throws -> SettingsKeychainSaveResult<EngineID> {
        var changed = false
        var saved: [EngineID: String] = [:]
        for engine in EngineID.allCases {
            let key = apiKeys[engine, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            if loadedKeys[engine, default: ""] != key {
                changed = true
            }
            do {
                if key.isEmpty {
                    try deleteEngineAPIKey(engine)
                } else {
                    try setEngineAPIKey(key, engine)
                }
            } catch {
                throw SettingsKeychainSaveError.engine(engine)
            }
            saved[engine] = key
        }
        return SettingsKeychainSaveResult(changed: changed, savedValues: saved)
    }

    func saveTTSAPIKey(
        _ apiKey: String,
        loadedKey: String,
        provider: TTSProviderID = .openai
    ) throws -> SettingsTTSKeySaveResult {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if key.isEmpty {
                try deleteTTSAPIKey(provider)
            } else {
                try setTTSAPIKey(key, provider)
            }
        } catch {
            throw SettingsKeychainSaveError.tts(provider)
        }
        return SettingsTTSKeySaveResult(changed: loadedKey != key, savedKey: key)
    }
}

struct SettingsSheet: View {
    let database: AppDatabase?
    let close: () -> Void
    let showToast: (String) -> Void

    @StateObject private var systemAppearance = SystemColorSchemeObserver()
    @State private var selectedTab: SettingsTab = .general
    @State private var apiKeys: [EngineID: String] = [:]
    @State private var loadedAPIKeys: [EngineID: String] = [:]
    @State private var models: [EngineID: String] = Dictionary(
        uniqueKeysWithValues: EngineID.allCases.map { ($0, ReaderFixtureStore.defaultModel(for: $0)) }
    )
    @State private var statuses: [EngineID: EngineStatusDot] = [:]
    @State private var testingEngine: EngineID?
    @State private var ttsAPIKey = ""
    @State private var loadedTTSAPIKey = ""
    @State private var ttsStatus: EngineStatusDot = .unset
    @State private var testingTTS = false
    @State private var cacheBytes: Int64 = 0
    @State private var audioCacheBytes: Int64 = 0
    @State private var bookCacheCandidate: String = ""
    @State private var books: [Book] = []
    @State private var localToast: String?
    @State private var launchAtLoginEnabled = false
    @State private var launchAtLoginStatus: LaunchAtLoginStatus = .disabled

    @AppStorage(LexiDefaultsKey.generalStartup) private var startupBehavior = "last"
    @AppStorage(LexiDefaultsKey.generalOnClose) private var closeBehavior = "menubar"
    @AppStorage(LexiDefaultsKey.engineDefaultChapter) private var defaultChapterEngine = EngineID.deepseek.rawValue
    @AppStorage(LexiDefaultsKey.engineDefaultPopup) private var defaultPopupEngine = EngineID.deepseek.rawValue
    @AppStorage(LexiDefaultsKey.ttsProvider) private var ttsProvider = TTSProviderID.openai.rawValue
    @AppStorage(LexiDefaultsKey.ttsDoubaoResourceId) private var ttsDoubaoResourceId = TTSProviderConfig.doubaoDefault.resourceId
    @AppStorage(LexiDefaultsKey.ttsDoubaoSpeaker) private var ttsDoubaoSpeaker = TTSProviderConfig.doubaoDefault.speaker
    @AppStorage(LexiDefaultsKey.ttsDoubaoSpeechRate) private var ttsDoubaoSpeechRate = TTSProviderConfig.doubaoDefault.speechRate
    @AppStorage(LexiDefaultsKey.ttsOpenAIModel) private var ttsOpenAIModel = TTSProviderConfig.openAIDefault.resourceId
    @AppStorage(LexiDefaultsKey.ttsOpenAIVoice) private var ttsOpenAIVoice = TTSProviderConfig.openAIDefault.speaker
    @AppStorage(LexiDefaultsKey.ttsOpenAISpeechRate) private var ttsOpenAISpeechRate = TTSProviderConfig.openAIDefault.speechRate
    @AppStorage(LexiDefaultsKey.readerFontSize) private var fontSize = 17.0
    @AppStorage(LexiDefaultsKey.readerSourceFont) private var sourceFont = ReaderFontChoice.defaultValue.rawValue
    @AppStorage(LexiDefaultsKey.readerTargetFont) private var targetFont = ReaderTargetFontChoice.defaultValue.rawValue
    @AppStorage(LexiDefaultsKey.readerLineHeight) private var lineHeight = "normal"
    @AppStorage(LexiDefaultsKey.readerTranslationMode) private var transMode = ReaderTranslationMode.both.rawValue
    @AppStorage(LexiDefaultsKey.readerParagraphLayout) private var paragraphLayout = ReaderParagraphLayout.defaultValue.rawValue
    @AppStorage(LexiDefaultsKey.readerTheme) private var theme = ReaderThemeMode.system.storageValue
    @AppStorage(LexiDefaultsKey.readerAccent) private var accent = "copper"
    @AppStorage(LexiDefaultsKey.readerPrefetch) private var prefetch = 1
    @AppStorage(LexiDefaultsKey.shortcutsConflictDetect) private var conflictDetect = true

    private var settingsAccent: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    private var settingsTheme: ReaderThemeChoice {
        ReaderThemeChoice(mode: themeMode, systemColorScheme: systemAppearance.colorScheme)
    }

    private var themeMode: ReaderThemeMode {
        ReaderThemeMode(storageValue: theme)
    }

    private var selectedTTSProvider: TTSProviderID {
        TTSProviderID(rawValue: ttsProvider) ?? .openai
    }

    private var selectedTTSDefaultConfig: TTSProviderConfig {
        TTSProviderConfig.defaultConfig(for: selectedTTSProvider)
    }

    private var ttsModelLabel: String {
        switch selectedTTSProvider {
        case .doubao:
            return "Resource ID"
        case .openai:
            return "模型"
        }
    }

    private var ttsModelHint: String {
        switch selectedTTSProvider {
        case .doubao:
            return "需与豆包音色匹配，默认 seed-tts-2.0"
        case .openai:
            return "OpenAI Speech API 模型，默认 gpt-4o-mini-tts"
        }
    }

    private var ttsModelPlaceholder: String {
        selectedTTSDefaultConfig.resourceId
    }

    private var ttsVoiceLabel: String {
        switch selectedTTSProvider {
        case .doubao:
            return "音色 ID"
        case .openai:
            return "声音"
        }
    }

    private var ttsVoiceHint: String {
        switch selectedTTSProvider {
        case .doubao:
            return "在火山控制台选择可用音色后填入 speaker"
        case .openai:
            return "内置声音 ID，推荐 marin；也可填 cedar / coral 等"
        }
    }

    private var ttsVoicePlaceholder: String {
        selectedTTSDefaultConfig.speaker
    }

    private var ttsKeyPlaceholder: String {
        switch selectedTTSProvider {
        case .doubao:
            return "X-Api-Key"
        case .openai:
            return "sk-..."
        }
    }

    private var ttsTestText: String {
        switch selectedTTSProvider {
        case .doubao:
            return "Lexi 正在测试豆包语音朗读。"
        case .openai:
            return "Lexi is testing OpenAI text to speech."
        }
    }

    private var currentTTSResourceId: String {
        switch selectedTTSProvider {
        case .doubao:
            return ttsDoubaoResourceId
        case .openai:
            return ttsOpenAIModel
        }
    }

    private var currentTTSSpeaker: String {
        switch selectedTTSProvider {
        case .doubao:
            return ttsDoubaoSpeaker
        case .openai:
            return ttsOpenAIVoice
        }
    }

    private var currentTTSSpeechRate: Int {
        switch selectedTTSProvider {
        case .doubao:
            return ttsDoubaoSpeechRate
        case .openai:
            return ttsOpenAISpeechRate
        }
    }

    private var ttsModelBinding: Binding<String> {
        Binding {
            currentTTSResourceId
        } set: { next in
            switch selectedTTSProvider {
            case .doubao:
                ttsDoubaoResourceId = next
            case .openai:
                ttsOpenAIModel = next
            }
        }
    }

    private var ttsVoiceBinding: Binding<String> {
        Binding {
            currentTTSSpeaker
        } set: { next in
            switch selectedTTSProvider {
            case .doubao:
                ttsDoubaoSpeaker = next
            case .openai:
                ttsOpenAIVoice = next
            }
        }
    }

    private var ttsSpeechRateBinding: Binding<Int> {
        Binding {
            currentTTSSpeechRate
        } set: { next in
            switch selectedTTSProvider {
            case .doubao:
                ttsDoubaoSpeechRate = next
            case .openai:
                ttsOpenAISpeechRate = next
            }
        }
    }

    private var themeBinding: Binding<String> {
        Binding {
            themeMode.storageValue
        } set: { next in
            theme = ReaderThemeMode(storageValue: next).storageValue
        }
    }

    private var paragraphLayoutBinding: Binding<String> {
        Binding {
            ReaderParagraphLayout(storageValue: paragraphLayout).rawValue
        } set: { next in
            paragraphLayout = ReaderParagraphLayout(storageValue: next).rawValue
        }
    }

    private var contentMaxWidth: CGFloat {
        switch selectedTab {
        case .engine, .readAloud:
            return 640
        default:
            return 620
        }
    }

    private var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "Lexi \(version) (build \(build))"
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                titleBar

                HStack(spacing: 0) {
                    sidebar
                        .frame(width: 180)

                    Rectangle()
                        .fill(Color.lexiRule)
                        .frame(width: 1)

                    ScrollView {
                        tabContent
                            .frame(maxWidth: contentMaxWidth, alignment: .top)
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 28)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .background(Color.lexiPaper)
                    .scrollIndicators(.visible)
                }
            }

            SettingsToast(text: localToast)
                .padding(.top, 48)
        }
        .frame(width: 720, height: 580)
        .background(settingsTheme.paper)
        .tint(settingsAccent.primary)
        .background(WindowAppearanceUpdater(colorScheme: themeMode.preferredColorScheme))
        .preferredColorScheme(themeMode.preferredColorScheme)
        .onChange(of: theme) { _, _ in
            systemAppearance.refresh()
        }
        .clipShape(RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: LexiRadius.window, style: .continuous)
                .stroke(Color.lexiRule, lineWidth: 1)
        }
        .task {
            await loadValues()
            refreshLaunchAtLoginStatus()
        }
        .onChange(of: defaultChapterEngine) { _, _ in
            NotificationCenter.default.post(name: .lexiChapterEngineSettingsChanged, object: nil)
        }
        .onChange(of: defaultPopupEngine) { _, _ in
            NotificationCenter.default.post(name: .lexiPopupEngineSettingsChanged, object: nil)
        }
        .onChange(of: ttsProvider) { previous, next in
            let previousProvider = TTSProviderID(rawValue: previous) ?? .openai
            let nextProvider = TTSProviderID(rawValue: next) ?? .openai
            if previousProvider != nextProvider {
                _ = saveTTSAPIKey(notify: false, provider: previousProvider)
            }
            loadTTSAPIKey(for: nextProvider)
        }
        .onDisappear {
            saveAPIKeys()
            persistDirtyEngineModelsOnDisappear()
            saveTTSAPIKey()
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
                        SettingsTabIcon(kind: tab.iconPath)
                            .stroke(
                                selectedTab == tab ? settingsAccent.primary : Color.lexiInk2,
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                            )
                            .frame(width: 14, height: 14)
                        Text(tab.title)
                            .font(LexiFont.zh(13))
                        Spacer()
                    }
                    .foregroundStyle(selectedTab == tab ? settingsAccent.primary : Color.lexiInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectedTab == tab ? settingsAccent.soft : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(appVersionText)
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
        case .readAloud:
            readAloudTab
        case .shortcuts:
            shortcutsTab
        case .reader:
            readerTab
        }
    }

    private var generalTab: some View {
        VStack(spacing: 0) {
            SettingsSection(title: "启动 / 退出") {
                SettingsRow(
                    label: "开机自启动",
                    hint: launchAtLoginHint
                ) {
                    LexiToggle(
                        isOn: Binding(
                            get: { launchAtLoginEnabled },
                            set: { setLaunchAtLogin($0) }
                        ),
                        accent: settingsAccent.primary
                    )
                }
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
                SettingsRow(label: "书籍与翻译缓存位置", isLast: true, controlWidth: 340) {
                    HStack(spacing: 8) {
                        Text("~/Library/Application Support/Lexi")
                            .font(LexiFont.mono(11))
                            .foregroundStyle(Color.lexiInk3)
                        Button {
                            toast("v1 暂不支持更改缓存路径")
                        } label: {
                            Text("更改…")
                        }
                        .buttonStyle(SettingsFlatButtonStyle())
                    }
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
                    SettingsRow(
                        label: engine.displayName,
                        hint: subtitle(for: engine),
                        isLast: index == EngineID.allCases.count - 1,
                        controlWidth: 290
                    ) {
                        EngineRow(
                            engine: engine,
                            status: statuses[engine] ?? (apiKeys[engine, default: ""].isEmpty ? .unset : .ok),
                            apiKey: binding(for: engine, in: $apiKeys),
                            model: binding(for: engine, in: $models),
                            testing: testingEngine == engine,
                            accent: settingsAccent,
                            test: {
                                test(engine)
                            },
                            onCommit: {
                                commitEngineSettings(engine)
                            }
                        )
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
                                .fill(settingsAccent.primary)
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

    private var readAloudTab: some View {
        VStack(spacing: 0) {
            SettingsSection(title: "AI 朗读") {
                SettingsRow(
                    label: "服务商",
                    hint: "OpenAI TTS 成本更友好；豆包语音保留为可选"
                ) {
                    SettingsSelect(
                        value: $ttsProvider,
                        options: TTSProviderID.allCases.map { ($0.rawValue, $0.displayName) }
                    )
                }
                SettingsRow(
                    label: ttsModelLabel,
                    hint: ttsModelHint
                ) {
                    TextField(ttsModelPlaceholder, text: ttsModelBinding)
                        .font(LexiFont.mono(11))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 190)
                }
                SettingsRow(
                    label: ttsVoiceLabel,
                    hint: ttsVoiceHint
                ) {
                    TextField(ttsVoicePlaceholder, text: ttsVoiceBinding)
                        .font(LexiFont.mono(11))
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 190)
                }
                SettingsRow(
                    label: "语速",
                    hint: "0 为默认；正数更快，负数更慢",
                    isLast: true
                ) {
                    Stepper(value: ttsSpeechRateBinding, in: -50...100, step: 10) {
                        Text("\(currentTTSSpeechRate)")
                            .font(LexiFont.mono(11))
                            .foregroundStyle(Color.lexiInk2)
                            .frame(width: 34, alignment: .trailing)
                    }
                    .controlSize(.small)
                }
            }

            SettingsSection(title: "API Key") {
                SettingsRow(
                    label: selectedTTSProvider.displayName,
                    hint: "Keychain 本地保存；不会进入 SQLite 或日志",
                    isLast: true,
                    controlWidth: 330
                ) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(ttsAPIKey.isEmpty ? Color.lexiInk4 : ttsStatus.color)
                            .frame(width: 6, height: 6)

                        SecureField(ttsKeyPlaceholder, text: $ttsAPIKey)
                            .font(LexiFont.mono(11))
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(width: 178)
                            .onChange(of: ttsAPIKey) { _, next in
                                ttsStatus = next.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .unset : .keyOkModelUnknown
                            }

                        Button {
                            testTTS()
                        } label: {
                            if testingTTS {
                                ProgressView()
                                    .controlSize(.mini)
                                    .frame(width: 28)
                            } else {
                                Text("测试")
                            }
                        }
                        .buttonStyle(SettingsFlatButtonStyle())
                        .disabled(testingTTS)
                    }
                }
            }

            SettingsSection(title: "朗读缓存") {
                SettingsRow(label: "音频缓存", isLast: true) {
                    HStack(spacing: 10) {
                        Text("\(Int(audioCacheBytesMB.rounded())) MB")
                            .font(LexiFont.mono(11))
                            .foregroundStyle(Color.lexiInk2)

                        Button("清除") {
                            clearAudioCache()
                        }
                        .buttonStyle(SettingsFlatButtonStyle())
                        .disabled(audioCacheBytes == 0)
                    }
                }
            }
        }
    }

    private var shortcutsTab: some View {
        VStack(spacing: 0) {
            SettingsSection(title: "阅读器") {
                ShortcutSettingsRow(label: "切换 仅原文/译文/双语", hint: "阅读器内生效", name: .readerToggleTranslationMode)
                ShortcutSettingsRow(label: "上一章", name: .readerPreviousChapter)
                ShortcutSettingsRow(label: "下一章", name: .readerNextChapter)
                ShortcutSettingsRow(label: "增大字号", name: .readerIncreaseFontSize)
                ShortcutSettingsRow(label: "减小字号", name: .readerDecreaseFontSize)
                ShortcutSettingsRow(label: "切换侧栏目录", name: .readerToggleSidebar, isLast: true)
            }

            SettingsSection(title: "导航") {
                ShortcutSettingsRow(label: "划词翻译", hint: "全局生效", name: .translateSelection)
                ShortcutSettingsRow(label: "即时翻译选中文字", hint: "不弹浮窗，替换选区", name: .translateAndReplaceSelection)
                ShortcutSettingsRow(label: "显示 / 隐藏阅读器", hint: "全局", name: .toggleReaderWindow, isLast: true)
            }

            SettingsSection(title: "") {
                SettingsRow(label: "冲突检测", hint: "当 Lexi 快捷键与系统或其他 app 冲突时提示", isLast: true) {
                    LexiToggle(isOn: $conflictDetect, accent: settingsAccent.primary)
                }
            }
        }
    }

    private var readerTab: some View {
        VStack(spacing: 0) {
            SettingsSection(title: "排版") {
                SettingsRow(label: "正文字号", hint: "也可在阅读时用 ⌘+ / ⌘- 临时调整", controlWidth: 250) {
                    HStack(spacing: 10) {
                        Text("\(Int(fontSize))pt")
                            .font(LexiFont.mono(11))
                            .foregroundStyle(Color.lexiInk3)
                            .frame(width: 28, alignment: .trailing)
                        Slider(value: $fontSize, in: 14...22, step: 1)
                            .tint(settingsAccent.primary)
                            .frame(width: 200)
                    }
                }
                SettingsRow(label: "原文字体", hint: "用于章节标题和原文段落") {
                    SettingsSelect(
                        value: $sourceFont,
                        options: sourceFontOptions
                    )
                }
                SettingsRow(label: "译文字体", hint: "用于目标语言段落") {
                    SettingsSelect(
                        value: $targetFont,
                        options: targetFontOptions
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
                SettingsRow(label: "段落布局") {
                    SettingsSegmented(
                        value: paragraphLayoutBinding,
                        options: [
                            (ReaderParagraphLayout.stacked.rawValue, "上下堆叠"),
                            (ReaderParagraphLayout.dual.rawValue, "左右双栏"),
                        ]
                    )
                }
                SettingsRow(label: "章节预取", hint: "后台预先翻译相邻章节", isLast: true) {
                    SettingsIntSegmented(
                        value: $prefetch,
                        options: [
                            (0, "0"),
                            (1, "1 章"),
                            (2, "2 章"),
                        ]
                    )
                }
            }

            SettingsSection(title: "主题") {
                SettingsRow(label: "模式") {
                    SettingsSegmented(
                        value: themeBinding,
                        options: [
                            (ReaderThemeMode.system.storageValue, "跟随系统"),
                            (ReaderThemeMode.day.storageValue, "白天"),
                            (ReaderThemeMode.night.storageValue, "夜间"),
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

    private var sourceFontOptions: [(String, String)] {
        [
            (ReaderFontChoice.newYork.rawValue, "New York"),
            (ReaderFontChoice.charter.rawValue, "Charter"),
            (ReaderFontChoice.iowanOldStyle.rawValue, "Iowan Old Style"),
            (ReaderFontChoice.georgia.rawValue, "Georgia"),
        ]
    }

    private var targetFontOptions: [(String, String)] {
        [
            (ReaderTargetFontChoice.system.rawValue, "系统默认"),
            (ReaderTargetFontChoice.pingFangSC.rawValue, "苹方"),
            (ReaderTargetFontChoice.songtiSC.rawValue, "宋体"),
            (ReaderTargetFontChoice.kaitiSC.rawValue, "楷体"),
            (ReaderTargetFontChoice.hiraginoSansGB.rawValue, "冬青黑体"),
        ]
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

    private var audioCacheBytesMB: Double {
        Double(audioCacheBytes) / 1024 / 1024
    }

    private func subtitle(for engine: EngineID) -> String {
        switch engine {
        case .openai:
            return "GPT-5.4 Mini / GPT-5.5"
        case .anthropic:
            return "Claude Sonnet / Haiku"
        case .deepseek:
            return "DeepSeek Chat / Reasoner"
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
        loadTTSAPIKey(for: selectedTTSProvider)
        cacheBytes = (try? await database?.translationCacheBytes()) ?? 0
        audioCacheBytes = (try? await database?.audioCacheBytes()) ?? 0
        books = (try? await database?.books()) ?? []
    }

    private var launchAtLoginHint: String {
        switch launchAtLoginStatus {
        case .enabled:
            return "macOS 登录后自动启动 Lexi"
        case .disabled:
            return "在系统登录项中注册或移除 Lexi"
        case .requiresApproval:
            return "需要在系统设置 → 登录项中允许 Lexi"
        case .unavailable:
            return "当前构建无法注册登录项"
        }
    }

    @MainActor
    private func refreshLaunchAtLoginStatus() {
        let status = LaunchAtLoginService.status
        launchAtLoginStatus = status
        launchAtLoginEnabled = status == .enabled || status == .requiresApproval
    }

    @MainActor
    private func setLaunchAtLogin(_ enabled: Bool) {
        let previousEnabled = launchAtLoginEnabled
        let previousStatus = launchAtLoginStatus
        launchAtLoginEnabled = enabled

        do {
            try LaunchAtLoginService.setEnabled(enabled)
            refreshLaunchAtLoginStatus()
            toast(launchAtLoginToast(for: launchAtLoginStatus, requestedEnabled: enabled))
        } catch {
            launchAtLoginEnabled = previousEnabled
            launchAtLoginStatus = previousStatus
            toast(enabled ? "开启开机自启动失败" : "关闭开机自启动失败")
        }
    }

    private func launchAtLoginToast(
        for status: LaunchAtLoginStatus,
        requestedEnabled: Bool
    ) -> String {
        if !requestedEnabled {
            return "已关闭开机自启动"
        }

        switch status {
        case .enabled:
            return "已开启开机自启动"
        case .requiresApproval:
            return "请在系统设置 → 登录项中允许 Lexi"
        case .disabled:
            return "开机自启动未开启"
        case .unavailable:
            return "当前构建无法注册登录项"
        }
    }

    private func test(_ engine: EngineID) {
        guard let key = apiKeys[engine], !key.isEmpty else {
            statuses[engine] = .unset
            do {
                try SettingsKeychainPersistence.live.deleteEngineAPIKey(engine)
                loadedAPIKeys[engine] = ""
            } catch {
                statuses[engine] = .fail
                toast("\(engine.displayName) API Key 删除失败，请重试")
                return
            }
            toast("请先填写 \(engine.displayName) API Key")
            return
        }

        let model = models[engine, default: ReaderFixtureStore.defaultModel(for: engine)]
        guard saveAPIKeys(notify: false) else {
            statuses[engine] = .fail
            return
        }
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

    private func commitEngineSettings(_ engine: EngineID) {
        let model = normalizedModel(for: engine)
        models[engine] = model
        statuses[engine] = apiKeys[engine, default: ""].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .unset
            : .keyOkModelUnknown

        Task {
            await persistUntestedEngineModel(engine, model: model, notify: true)
        }
    }

    private func persistDirtyEngineModelsOnDisappear() {
        let currentModels = Dictionary(
            uniqueKeysWithValues: EngineID.allCases.map { engine in
                (engine, normalizedModel(for: engine))
            }
        )

        Task {
            await persistDirtyEngineModels(currentModels)
        }
    }

    private func persistDirtyEngineModels(_ currentModels: [EngineID: String]) async {
        guard let database else {
            return
        }

        var changed = false
        for engine in EngineID.allCases {
            let model = currentModels[engine, default: ReaderFixtureStore.defaultModel(for: engine)]
            let stored = try? await database.engineConfig(for: engine)
            if stored?.model == model {
                continue
            }
            if stored == nil, model == ReaderFixtureStore.defaultModel(for: engine) {
                continue
            }
            try? await database.upsertEngineConfig(settingsUntestedEngineConfig(for: engine, model: model))
            changed = true
        }

        if changed {
            notifyEngineSettingsChanged()
        }
    }

    private func persistUntestedEngineModel(_ engine: EngineID, model: String, notify: Bool) async {
        try? await database?.upsertEngineConfig(settingsUntestedEngineConfig(for: engine, model: model))
        if notify {
            notifyEngineSettingsChanged()
        }
    }

    private func normalizedModel(for engine: EngineID) -> String {
        let model = models[engine, default: ReaderFixtureStore.defaultModel(for: engine)]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? ReaderFixtureStore.defaultModel(for: engine) : model
    }

    private func testTTS() {
        let providerID = selectedTTSProvider
        let key = ttsAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            ttsStatus = .unset
            do {
                try SettingsKeychainPersistence.live.deleteTTSAPIKey(providerID)
                loadedTTSAPIKey = ""
            } catch {
                ttsStatus = .fail
                toast("\(providerID.displayName) API Key 删除失败，请重试")
                return
            }
            toast("请先填写 \(providerID.displayName) API Key")
            return
        }

        guard !currentTTSConfig.speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            ttsStatus = .fail
            toast("请先填写\(ttsVoiceLabel)")
            return
        }

        guard saveTTSAPIKey(notify: false) else {
            ttsStatus = .fail
            return
        }
        testingTTS = true
        Task {
            do {
                let provider = try TTSRegistry.shared.provider(for: currentTTSConfig)
                _ = try await provider.ping(TTSRequest(
                    text: ttsTestText,
                    config: currentTTSConfig,
                    contextInstruction: "Read naturally with clear phrasing."
                ))
                ttsStatus = .ok
                toast("\(providerID.displayName) 连接成功")
            } catch {
                ttsStatus = .fail
                toast(error.localizedDescription)
            }
            testingTTS = false
        }
    }

    private func loadTTSAPIKey(for provider: TTSProviderID) {
        ttsAPIKey = TTSKeychain.apiKey(for: provider) ?? ""
        loadedTTSAPIKey = ttsAPIKey
        ttsStatus = ttsAPIKey.isEmpty ? .unset : .ok
    }

    @discardableResult
    private func saveAPIKeys(notify: Bool = true) -> Bool {
        do {
            let result = try SettingsKeychainPersistence.live.saveEngineAPIKeys(apiKeys: apiKeys, loadedKeys: loadedAPIKeys)
            loadedAPIKeys = result.savedValues
            if notify, result.changed {
                notifyEngineSettingsChanged()
            }
            return true
        } catch let error as SettingsKeychainSaveError {
            if case .engine(let engine) = error {
                statuses[engine] = .fail
                toast("\(engine.displayName) API Key 保存失败，请重试")
            } else {
                toast("API Key 保存失败，请重试")
            }
            return false
        } catch {
            toast("API Key 保存失败，请重试")
            return false
        }
    }

    @discardableResult
    private func saveTTSAPIKey(notify: Bool = true, provider explicitProvider: TTSProviderID? = nil) -> Bool {
        let providerID = explicitProvider ?? selectedTTSProvider
        do {
            let result = try SettingsKeychainPersistence.live.saveTTSAPIKey(ttsAPIKey, loadedKey: loadedTTSAPIKey, provider: providerID)
            loadedTTSAPIKey = result.savedKey
            ttsStatus = result.savedKey.isEmpty ? .unset : ttsStatus
            if notify, result.changed {
                toast("已更新 \(providerID.displayName) Key")
            }
            return true
        } catch {
            ttsStatus = .fail
            toast("\(providerID.displayName) API Key 保存失败，请重试")
            return false
        }
    }

    private var currentTTSConfig: TTSProviderConfig {
        let defaultConfig = selectedTTSDefaultConfig
        let trimmedResource = currentTTSResourceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSpeaker = currentTTSSpeaker.trimmingCharacters(in: .whitespacesAndNewlines)
        return TTSProviderConfig(
            provider: selectedTTSProvider,
            resourceId: trimmedResource.isEmpty ? defaultConfig.resourceId : trimmedResource,
            speaker: trimmedSpeaker.isEmpty ? defaultConfig.speaker : trimmedSpeaker,
            speechRate: currentTTSSpeechRate,
            format: defaultConfig.format,
            sampleRate: defaultConfig.sampleRate
        )
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

    private func clearAudioCache() {
        Task {
            try? await database?.clearAudioCache()
            if let directory = try? AudioCacheLocation.directory() {
                try? FileManager.default.removeItem(at: directory)
            }
            audioCacheBytes = 0
            toast("已清除音频缓存")
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

nonisolated func settingsUntestedEngineConfig(for engine: EngineID, model: String) -> EngineConfig {
    EngineConfig(id: engine, model: model, lastTestedOK: false, lastTestedAt: nil)
}
