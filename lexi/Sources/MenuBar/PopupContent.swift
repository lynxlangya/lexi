import SwiftUI

enum PopupKind: Equatable {
    case chip(text: String)
    case loading(text: String, isWord: Bool, engine: EngineID)
    case word(WordLookup)
    case sentence(SentenceLookup)
    case error(text: String, reason: String)
}

struct WordLookup: Equatable {
    var word: String
    var ukIPA: String
    var usIPA: String
    var senses: [WordSense]
    var example: WordExample?
    var related: [String]
    var engine: EngineID
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
}

struct PopupActions {
    var close: () -> Void
    var togglePin: () -> Void
    var translateChip: () -> Void
    var retry: () -> Void
    var addVocab: () -> Void
    var speak: (String) -> Void
    var selectEngine: (EngineID) -> Void
}

struct PopupContent: View {
    let kind: PopupKind
    let pinned: Bool
    let actions: PopupActions

    var body: some View {
        switch kind {
        case .chip:
            TriggerChip(action: actions.translateChip)
        case .loading(let text, _, let engine):
            LoadingCard(text: text, engine: engine)
        case .word(let lookup):
            WordCard(lookup: lookup, pinned: pinned, actions: actions)
        case .sentence(let lookup):
            SentenceCard(lookup: lookup, pinned: pinned, actions: actions)
        case .error(_, let reason):
            ErrorCard(reason: reason, retry: actions.retry, close: actions.close)
        }
    }
}

struct PopupHeaderActions: View {
    let pinned: Bool
    let actions: PopupActions
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    var body: some View {
        HStack(spacing: 2) {
            Button(action: actions.togglePin) {
                Image(systemName: "pin")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 18, height: 18)
                    .background(pinned ? accentChoice.soft : Color.clear)
                    .foregroundStyle(pinned ? accentChoice.primary : Color.lexiInk3)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .buttonStyle(.plain)
            .help(pinned ? "取消固定" : "固定")

            Button(action: actions.close) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Color.lexiInk3)
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")
        }
    }
}

struct PopupFrame<Content: View>: View {
    let pinned: Bool
    @ViewBuilder var content: Content
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content
            if pinned {
                Circle()
                    .fill(accentChoice.primary)
                    .frame(width: 6, height: 6)
                    .padding(9)
            }
        }
        .background(Color.clear)
    }
}

private struct TriggerChip: View {
    let action: () -> Void
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                LexiGlyph(color: accentChoice.primary, size: 12)
                Text("译")
                    .font(LexiFont.sans(10))
                    .fontWeight(.semibold)
                    .foregroundStyle(accentChoice.primary)
            }
            .frame(width: 32, height: 22)
            .background(Color.lexiRaised)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.lexiRule, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }
}
