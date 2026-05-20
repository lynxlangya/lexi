import SwiftUI

struct WordCard: View {
    let lookup: WordLookup
    let pinned: Bool
    let actions: PopupActions

    var body: some View {
        PopupFrame(pinned: pinned) {
            VStack(spacing: 0) {
                if !lookup.history.isEmpty {
                    recentBar
                }

                header

                VStack(alignment: .leading, spacing: 14) {
                    titleRow
                    senses
                    related
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)

                footer
            }
            .frame(width: 420)
        }
    }

    private var recentBar: some View {
        HStack(spacing: 6) {
            Text("近期")
                .font(LexiFont.sans(9.5))
                .fontWeight(.semibold)
                .foregroundStyle(Color.lexiInk3)
                .tracking(1)

            ForEach(lookup.history.prefix(5), id: \.self) { word in
                Text(word)
                    .font(LexiFont.sans(11))
                    .foregroundStyle(Color.lexiInk2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lexiInset)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().stroke(Color.lexiRule, lineWidth: 1)
                    }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.lexiChrome)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lexiRule).frame(height: 1)
        }
    }

    private var header: some View {
        HStack {
            Text("Lexi · 单词卡")
                .font(LexiFont.sans(11))
                .fontWeight(.semibold)
                .foregroundStyle(Color.lexiInk3)
                .tracking(0.6)
            Spacer()
            PopupHeaderActions(pinned: pinned, actions: actions)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.lexiRule).frame(height: 1)
        }
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lookup.word)
                .font(LexiFont.serif(30))
                .foregroundStyle(Color.lexiInk)

            HStack(spacing: 14) {
                ipa(label: "UK", value: lookup.ukIPA)
                ipa(label: "US", value: lookup.usIPA)
            }
        }
    }

    private func ipa(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(LexiFont.mono(11.5))
                .foregroundStyle(Color.lexiInk3)
            Text(value)
                .font(LexiFont.mono(12.5))
                .foregroundStyle(Color.lexiInk2)
            Button {
                actions.speak(lookup.word)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lexiInk3)
            }
            .buttonStyle(.plain)
        }
    }

    private var senses: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(lookup.senses.enumerated()), id: \.element.id) { index, sense in
                HStack(alignment: .top, spacing: 12) {
                    Text(sense.partOfSpeech)
                        .font(LexiFont.serif(12.5))
                        .italic()
                        .foregroundStyle(Color.lexiAccent)
                        .frame(width: 36, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(sense.en)
                            .font(LexiFont.serif(14))
                            .lineSpacing(7)
                            .foregroundStyle(Color.lexiInk)
                        Text(sense.zh)
                            .font(LexiFont.zh(13))
                            .lineSpacing(8)
                            .foregroundStyle(Color.lexiInk2)

                        if index == 0, let example = lookup.example {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\"\(example.en)\"")
                                    .font(LexiFont.serif(12))
                                    .italic()
                                    .foregroundStyle(Color.lexiInk2)
                                Text(example.zh)
                                    .font(LexiFont.zh(11.5))
                                    .foregroundStyle(Color.lexiInk3)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.lexiInset)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.lexiRule, lineWidth: 1)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var related: some View {
        if !lookup.related.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("相关")
                    .font(LexiFont.sans(10))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lexiInk3)
                    .tracking(1)

                ForEach(lookup.related, id: \.self) { word in
                    Text(word)
                        .font(LexiFont.serif(12))
                        .italic()
                        .foregroundStyle(Color.lexiInk2)
                        .overlay(alignment: .bottom) {
                            DottedRule()
                                .stroke(Color.lexiRule2, style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
                                .frame(height: 1)
                        }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 2) {
                ForEach(EngineID.allCases, id: \.self) { engine in
                    EnginePill(engine: engine, active: lookup.engine == engine) {
                        actions.selectEngine(engine)
                    }
                }
            }

            Spacer()

            Button {
                actions.addVocab()
            } label: {
                Label("生词本", systemImage: "plus")
                    .font(LexiFont.sans(11.5))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.lexiChrome)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.lexiRule).frame(height: 1)
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
