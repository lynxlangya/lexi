import SwiftUI

struct EnginePill: View {
    let engine: EngineID
    let active: Bool
    let theme: PopupTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(engine.menuLabel)
                .font(LexiFont.sans(10.5))
                .fontWeight(active ? .semibold : .medium)
                .foregroundStyle(active ? theme.accent.primary : theme.ink3)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(active ? theme.accent.soft : Color.clear)
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
