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

                        Text(lookup.zh + (lookup.isStreaming ? " ..." : ""))
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
            if lookup.isStreaming {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)

                    Text("生成中")
                        .font(LexiFont.sans(10.5))
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.ink2)
                }

                Spacer()
            } else {
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
}
