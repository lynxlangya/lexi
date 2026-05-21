import SwiftUI

struct WordCard: View {
    let lookup: WordLookup
    let pinned: Bool
    let actions: PopupActions

    var body: some View {
        PopupThemeReader { theme in
            PopupCard(width: 320, pinned: pinned, theme: theme) {
                VStack(spacing: 0) {
                    PopupHeader(
                        label: "Lexi · 单词",
                        pinned: pinned,
                        actions: actions,
                        theme: theme
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        titleLine(theme: theme)
                            .padding(.bottom, 14)

                        senses(theme: theme)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                    footer(theme: theme)
                }
            }
        }
    }

    private func titleLine(theme: PopupTheme) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 11) {
            Text(lookup.word)
                .font(LexiFont.serif(24))
                .fontWeight(.medium)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(primaryIPA)
                .font(LexiFont.mono(14))
                .foregroundStyle(theme.ink3)
                .lineLimit(1)

            Button {
                actions.speak(lookup.word)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(theme.ink3)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("朗读")

            Spacer(minLength: 0)
        }
    }

    private var primaryIPA: String {
        if !lookup.ukIPA.isEmpty {
            lookup.ukIPA
        } else {
            lookup.usIPA
        }
    }

    private func senses(theme: PopupTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(lookup.senses.prefix(2).enumerated()), id: \.element.id) { _, sense in
                HStack(alignment: .top, spacing: 11) {
                    Text(sense.partOfSpeech)
                        .font(LexiFont.serif(11.5))
                        .italic()
                        .foregroundStyle(theme.accent.primary)
                        .frame(width: 28, alignment: .leading)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sense.en)
                            .font(LexiFont.serif(13))
                            .lineSpacing(6)
                            .foregroundStyle(theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(sense.zh)
                            .font(LexiFont.zh(12))
                            .lineSpacing(7)
                            .foregroundStyle(theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

            PopupPrimaryButton(theme: theme, action: actions.addVocab) {
                Label("生词本", systemImage: "plus")
            }
        }
    }
}
