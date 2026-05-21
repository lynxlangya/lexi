import SwiftUI

struct LoadingCard: View {
    let text: String
    let engine: EngineID

    var body: some View {
        PopupThemeReader { theme in
            PopupCard(width: 420, pinned: false, theme: theme) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Lexi · 翻译中".uppercased())
                            .font(LexiFont.sans(11))
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.ink3)
                            .tracking(0.7)

                        Spacer()

                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                            Text(engine.menuLabel)
                                .font(LexiFont.sans(10.5))
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(theme.accent.primary)
                    }
                    .frame(height: 56)
                    .padding(.horizontal, 20)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.rule)
                            .frame(height: 1)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("\"\(text)\"")
                            .font(LexiFont.serif(15))
                            .italic()
                            .lineSpacing(8)
                            .foregroundStyle(theme.ink2)
                            .lineLimit(3)

                        Rectangle()
                            .fill(theme.rule)
                            .frame(height: 1)

                        VStack(alignment: .leading, spacing: 9) {
                            ShimmerLine(width: 1, theme: theme)
                            ShimmerLine(width: 0.9, theme: theme)
                            ShimmerLine(width: 0.62, theme: theme)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            }
        }
    }
}

private struct ShimmerLine: View {
    let width: CGFloat
    let theme: PopupTheme

    var body: some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.shimmer1, theme.shimmer2, theme.shimmer1],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: proxy.size.width * width, height: 11)
        }
        .frame(height: 11)
    }
}
