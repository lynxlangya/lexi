import SwiftUI

struct EnginePill: View {
    let engine: EngineID
    let active: Bool
    let action: () -> Void
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    var body: some View {
        Button(action: action) {
            Text(engine.menuLabel)
                .font(LexiFont.sans(10.5))
                .fontWeight(active ? .semibold : .medium)
                .foregroundStyle(active ? accentChoice.primary : Color.lexiInk3)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(active ? accentChoice.soft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

extension EngineID {
    var menuLabel: String {
        switch self {
        case .openai:
            return "GPT"
        case .anthropic:
            return "Claude"
        case .deepseek:
            return "DeepSeek"
        }
    }
}
