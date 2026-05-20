import SwiftUI

struct ToastMessage: Equatable, Identifiable {
    let id = UUID()
    let text: String
}

struct ToastView: View {
    let message: ToastMessage?
    var preferences: ReaderRuntimePreferences?

    private var theme: ReaderThemeChoice {
        preferences?.theme ?? ReaderThemeChoice(storageValue: ReaderThemeMode.system.storageValue)
    }

    var body: some View {
        if let message {
            Text(message.text)
                .font(LexiFont.zh(12.5))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(theme.raised)
                .clipShape(RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous))
                .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: LexiRadius.control, style: .continuous)
                        .stroke(theme.rule, lineWidth: 1)
                }
                .padding(.top, 18)
                .transition(.move(edge: .top).combined(with: .opacity))
                .id(message.id)
        }
    }
}
