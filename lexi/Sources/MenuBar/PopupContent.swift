import SwiftUI

enum PopupKind: Equatable {
    case loading(text: String, isWord: Bool, engine: EngineID)
    case word(WordLookup)
    case sentence(SentenceLookup)
    case error(text: String, reason: String)
    case permissionError(reason: String)
}

struct WordLookup: Equatable {
    var word: String
    var ukIPA: String
    var usIPA: String
    var senses: [WordSense]
    var example: WordExample?
    var related: [String]
    var engine: EngineID
    var model: String
    var history: [String]
}

struct WordSense: Equatable, Identifiable {
    let id = UUID()
    var partOfSpeech: String
    var en: String
    var zh: String
}

struct WordExample: Equatable {
    var en: String
    var zh: String
}

struct SentenceLookup: Equatable {
    var text: String
    var zh: String
    var engine: EngineID
    var model: String
}

struct PopupActions {
    var close: () -> Void
    var togglePin: () -> Void
    var retry: () -> Void
    var addVocab: () -> Void
    var speak: (String) -> Void
    var selectEngine: (EngineID) -> Void
    var openSettings: () -> Void
    var openAccessibilitySettings: () -> Void
}

struct PopupContent: View {
    let kind: PopupKind
    let pinned: Bool
    let actions: PopupActions

    var body: some View {
        switch kind {
        case .loading(let text, _, let engine):
            LoadingCard(text: text, engine: engine)
        case .word(let lookup):
            WordCard(lookup: lookup, pinned: pinned, actions: actions)
        case .sentence(let lookup):
            SentenceCard(lookup: lookup, pinned: pinned, actions: actions)
        case .error(_, let reason):
            ErrorCard(
                title: "连接引擎失败",
                message: "检查网络、API Key 或模型名后重试。",
                reason: reason,
                actionTitle: "去设置 →",
                action: actions.openSettings,
                retry: actions.retry,
                close: actions.close
            )
        case .permissionError(let reason):
            ErrorCard(
                title: "需要辅助功能权限",
                message: "Lexi 需要读取当前选区，授权后才能划词翻译。",
                reason: reason,
                actionTitle: "打开系统设置 →",
                action: actions.openAccessibilitySettings,
                retry: nil,
                close: actions.close
            )
        }
    }
}

struct PopupHeaderActions: View {
    let pinned: Bool
    let actions: PopupActions
    let theme: PopupTheme

    var body: some View {
        HStack(spacing: 3) {
            Button(action: actions.togglePin) {
                Image(systemName: "pin")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 20, height: 20)
                    .background(pinned ? theme.accent.soft : Color.clear)
                    .foregroundStyle(pinned ? theme.accent.primary : theme.ink3)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(pinned ? "取消固定" : "固定")

            Button(action: actions.close) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(theme.ink3)
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")
        }
    }
}
