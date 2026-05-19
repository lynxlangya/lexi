import SwiftUI

struct ReaderToolbar: View {
    let bookTitle: String
    let chapter: DemoChapter
    let chapterIndex: Int
    let chapterCount: Int
    @Binding var fontSize: Double

    var body: some View {
        ZStack {
            Text("\(bookTitle) · Chapter \(chapter.n) · \(chapterIndex + 1)/\(chapterCount)")
                .font(LexiFont.sans(12))
                .foregroundStyle(Color.lexiInk3)
                .lineLimit(1)

            HStack(spacing: 2) {
                Spacer()

                ToolbarIconButton(systemName: "sidebar.left", isActive: true) {}

                ToolbarDivider()

                ToolbarTextButton(label: "A-") {
                    fontSize = max(14, fontSize - 1)
                }

                ToolbarTextButton(label: "A+") {
                    fontSize = min(22, fontSize + 1)
                }

                ToolbarDivider()

                ToolbarIconButton(systemName: "translate") {}
                ToolbarIconButton(systemName: "gearshape") {}
                ToolbarIconButton(systemName: "moon") {}
                ToolbarIconButton(systemName: "ellipsis") {}
            }
        }
        .padding(.leading, 96)
        .padding(.trailing, 12)
        .frame(height: 44)
        .background(Color.lexiChrome)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lexiRule)
                .frame(height: 1)
        }
    }
}

private struct ToolbarIconButton: View {
    let systemName: String
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .regular))
                .frame(width: 26, height: 22)
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(ToolbarButtonStyle(isActive: isActive))
        .focusable(false)
    }
}

private struct ToolbarTextButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(LexiFont.sans(11.5))
                .fontWeight(.medium)
                .frame(width: 26, height: 22)
                .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(ToolbarButtonStyle())
        .focusable(false)
    }
}

private struct ToolbarButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isActive ? Color.lexiAccent : Color.lexiInk3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(background(configuration: configuration))
            )
    }

    private func background(configuration: Configuration) -> Color {
        if isActive {
            return Color.lexiAccentSoft
        }
        return configuration.isPressed ? Color.lexiAccentFaint : Color.clear
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.lexiRule)
            .frame(width: 1, height: 14)
            .padding(.horizontal, 6)
    }
}
