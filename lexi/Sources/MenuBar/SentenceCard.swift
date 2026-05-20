import SwiftUI

struct SentenceCard: View {
    let lookup: SentenceLookup
    let pinned: Bool
    let actions: PopupActions

    var body: some View {
        PopupFrame(pinned: pinned) {
            VStack(spacing: 0) {
                HStack {
                    Text("Lexi · 整句")
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

                VStack(alignment: .leading, spacing: 14) {
                    Text("\"\(lookup.text)\"")
                        .font(LexiFont.serif(14))
                        .italic()
                        .lineSpacing(8)
                        .foregroundStyle(Color.lexiInk2)

                    Rectangle()
                        .fill(Color.lexiRule)
                        .frame(height: 1)

                    Text(lookup.zh)
                        .font(LexiFont.zh(14.5))
                        .lineSpacing(11)
                        .foregroundStyle(Color.lexiInk)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)

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
                        actions.speak(lookup.zh)
                    } label: {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lexiInk3)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.lexiChrome)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.lexiRule).frame(height: 1)
                }
            }
            .frame(width: 420)
        }
    }
}
