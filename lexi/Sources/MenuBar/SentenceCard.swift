import SwiftUI

struct SentenceCard: View {
    let lookup: SentenceLookup
    let pinned: Bool
    let actions: PopupActions

    var body: some View {
        PopupThemeReader { theme in
            PopupCard(width: 340, pinned: pinned, theme: theme) {
                VStack(spacing: 0) {
                    PopupHeader(
                        label: "Lexi · 整句",
                        pinned: pinned,
                        actions: actions,
                        theme: theme
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("\"\(lookup.text)\"")
                            .font(LexiFont.serif(13.5))
                            .italic()
                            .lineSpacing(7)
                            .foregroundStyle(theme.ink2)
                            .lineLimit(5)
                            .fixedSize(horizontal: false, vertical: true)

                        Rectangle()
                            .fill(theme.rule)
                            .frame(height: 1)
                            .padding(.vertical, 14)

                        Text(lookup.zh)
                            .font(LexiFont.zh(14))
                            .lineSpacing(10)
                            .foregroundStyle(theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .textSelection(.enabled)

                    footer(theme: theme)
                }
            }
        }
    }

    private func footer(theme: PopupTheme) -> some View {
        PopupFooter(theme: theme) {
            PopupEngineLabel(engine: lookup.engine, model: lookup.model, theme: theme)

            Spacer()

            PopupOutlineButton(theme: theme) {
                actions.speak(lookup.zh)
            } label: {
                Label("朗读", systemImage: "speaker.wave.2")
            }
        }
    }
}
