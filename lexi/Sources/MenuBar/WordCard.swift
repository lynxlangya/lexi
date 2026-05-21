import SwiftUI

struct WordCard: View {
    let lookup: WordLookup
    let pinned: Bool
    let actions: PopupActions

    var body: some View {
        PopupThemeReader { theme in
            PopupCard(width: 640, pinned: pinned, theme: theme) {
                VStack(spacing: 0) {
                    PopupHeader(
                        label: "Lexi · 单词",
                        pinned: pinned,
                        actions: actions,
                        theme: theme
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        titleRow(theme: theme)
                            .padding(.bottom, 28)

                        senses(theme: theme)

                        related(theme: theme)
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 28)
                    .padding(.bottom, 30)
                    .frame(minHeight: 398, alignment: .topLeading)

                    footer(theme: theme)
                }
            }
        }
    }

    private func titleRow(theme: PopupTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lookup.word)
                .font(LexiFont.serif(42))
                .foregroundStyle(theme.ink)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 16) {
                ipa(label: "UK", value: lookup.ukIPA, theme: theme)
                ipa(label: "US", value: lookup.usIPA, theme: theme)

                Button {
                    actions.speak(lookup.word)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(theme.ink3)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("朗读")
            }
        }
    }

    private func ipa(label: String, value: String, theme: PopupTheme) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .font(LexiFont.mono(11.5))
                .fontWeight(.medium)
                .foregroundStyle(theme.ink3)
            Text(value)
                .font(LexiFont.mono(12.5))
                .foregroundStyle(theme.ink2)
        }
    }

    private func senses(theme: PopupTheme) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            ForEach(Array(lookup.senses.enumerated()), id: \.element.id) { index, sense in
                HStack(alignment: .top, spacing: 18) {
                    Text(sense.partOfSpeech)
                        .font(LexiFont.serif(15))
                        .italic()
                        .foregroundStyle(theme.accent.primary)
                        .frame(width: 46, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(sense.en)
                            .font(LexiFont.serif(16))
                            .lineSpacing(8)
                            .foregroundStyle(theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(sense.zh)
                            .font(LexiFont.zh(14.5))
                            .lineSpacing(8)
                            .foregroundStyle(theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)

                        if index == 0, let example = lookup.example {
                            exampleBlock(example, theme: theme)
                                .padding(.top, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func exampleBlock(_ example: WordExample, theme: PopupTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\"\(example.en)\"")
                .font(LexiFont.serif(13))
                .italic()
                .lineSpacing(6)
                .foregroundStyle(theme.ink2)
            Text(example.zh)
                .font(LexiFont.zh(12.5))
                .lineSpacing(7)
                .foregroundStyle(theme.ink3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgInset)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(theme.rule, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func related(theme: PopupTheme) -> some View {
        if !lookup.related.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("相关")
                    .font(LexiFont.sans(10.5))
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.ink3)
                    .tracking(1)

                ForEach(lookup.related, id: \.self) { word in
                    Text(word)
                        .font(LexiFont.serif(13))
                        .italic()
                        .foregroundStyle(theme.ink2)
                        .overlay(alignment: .bottom) {
                            DottedRule()
                                .stroke(theme.rule2, style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
                                .frame(height: 1)
                                .offset(y: 2)
                        }
                }
            }
            .padding(.top, 22)
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

private struct DottedRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
