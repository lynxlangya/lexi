import SwiftUI

struct SentenceCard: View {
    let lookup: SentenceLookup
    let pinned: Bool
    let actions: PopupActions

    var body: some View {
        PopupThemeReader { theme in
            PopupCard(width: 678, pinned: pinned, theme: theme) {
                VStack(spacing: 0) {
                    PopupHeader(
                        label: "Lexi · 整句",
                        pinned: pinned,
                        actions: actions,
                        theme: theme
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        Text("\"\(lookup.text)\"")
                            .font(LexiFont.serif(19))
                            .italic()
                            .lineSpacing(12)
                            .foregroundStyle(theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)

                        Rectangle()
                            .fill(theme.rule)
                            .frame(height: 1)
                            .padding(.vertical, 26)

                        Text(lookup.zh)
                            .font(LexiFont.zh(20))
                            .lineSpacing(16)
                            .foregroundStyle(theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 30)
                    .padding(.bottom, 34)
                    .frame(minHeight: 316, alignment: .topLeading)

                    footer(theme: theme)
                }
            }
        }
    }

    private func footer(theme: PopupTheme) -> some View {
        PopupFooter(theme: theme) {
            HStack(spacing: 2) {
                ForEach(EngineID.allCases, id: \.self) { engine in
                    EnginePill(engine: engine, active: lookup.engine == engine, theme: theme) {
                        actions.selectEngine(engine)
                    }
                }
            }

            Spacer()

            PopupOutlineButton(theme: theme) {
                actions.speak(lookup.zh)
            } label: {
                Label("朗读", systemImage: "speaker.wave.2")
            }
        }
    }
}
