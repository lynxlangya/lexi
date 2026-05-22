import SwiftUI

struct ShimmerLines: View {
    let fontSize: CGFloat
    let theme: ReaderThemeChoice
    var preferredLineCount: Int? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.6) / 1.6

            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<lineCount, id: \.self) { index in
                    shimmerLine(
                        width: width(for: index),
                        phase: phase + Double(index) * 0.06
                    )
                }
            }
        }
    }

    private var lineCount: Int {
        max(1, preferredLineCount ?? 2)
    }

    private func width(for index: Int) -> CGFloat {
        index == lineCount - 1 ? 0.64 : 0.92
    }

    private func shimmerLine(width: CGFloat, phase: Double) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.shimmer1, theme.shimmer2, theme.shimmer1],
                        startPoint: UnitPoint(x: phase - 1, y: 0.5),
                        endPoint: UnitPoint(x: phase, y: 0.5)
                    )
                )
                .frame(width: proxy.size.width * width, height: fontSize * 0.7)
        }
        .frame(height: fontSize * 0.7)
    }
}

struct SpinnerDot: View {
    var size: CGFloat = 10
    var accent: Color = .lexiAccent

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { context in
            let angle = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.2) / 1.2 * 360

            Image(systemName: "progress.indicator")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(accent)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: size, height: size)
    }
}
