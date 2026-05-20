import SwiftUI

struct LoadingCard: View {
    let text: String
    let engine: EngineID
    @AppStorage("reader.accent") private var accent = "copper"

    private var accentChoice: ReaderAccentChoice {
        ReaderAccentChoice(storageValue: accent)
    }

    var body: some View {
        PopupFrame(pinned: false) {
            VStack(spacing: 0) {
                HStack {
                    Text("Lexi · 翻译中")
                        .font(LexiFont.sans(11))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lexiInk3)
                        .tracking(0.6)
                    Spacer()
                    HStack(spacing: 5) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(engine.menuLabel)
                            .font(LexiFont.sans(10.5))
                    }
                    .foregroundStyle(accentChoice.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.lexiRule).frame(height: 1)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("\"\(text)\"")
                        .font(LexiFont.serif(13.5))
                        .italic()
                        .lineSpacing(7)
                        .foregroundStyle(Color.lexiInk2)
                        .lineLimit(3)

                    Rectangle()
                        .fill(Color.lexiRule)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        ShimmerLine(width: 1)
                        ShimmerLine(width: 0.9)
                        ShimmerLine(width: 0.6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .frame(width: 340)
        }
    }
}

private struct ShimmerLine: View {
    let width: CGFloat

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.lexiShimmer1, Color.lexiShimmer2, Color.lexiShimmer1],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.width * width, height: 11)
        }
        .frame(height: 11)
    }
}
