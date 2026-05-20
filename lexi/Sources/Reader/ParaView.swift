import SwiftUI

struct ParaView: View {
    let paragraph: ReaderParagraph
    let fontSize: Double
    let state: ParagraphTranslationState
    let transMode: ReaderTranslationMode
    let retry: () -> Void
    let addVocab: () -> Void

    private var enSize: CGFloat {
        CGFloat(fontSize)
    }

    private var zhSize: CGFloat {
        CGFloat(fontSize * 13.5 / 17.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LexiSpacing.enZhGap) {
            if transMode != .zh {
                Text(paragraph.en)
                    .font(LexiFont.serif(enSize))
                    .lineSpacing(enSize * 0.72)
                    .foregroundStyle(Color.lexiInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if transMode != .en {
                translation
            }

            if transMode != .zh {
                Button(action: addVocab) {
                    Label("生词本", systemImage: "plus")
                        .font(LexiFont.zh(11.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.lexiInk3)
            }
        }
        .padding(.bottom, LexiSpacing.paraGap)
    }

    @ViewBuilder
    private var translation: some View {
        switch state {
        case .cached(let zh):
            Text(zh)
                .font(LexiFont.zh(zhSize))
                .lineSpacing(zhSize * 0.78)
                .foregroundStyle(Color.lexiInk2)
                .fixedSize(horizontal: false, vertical: true)
        case .translating:
            ShimmerLines(fontSize: zhSize)
        case .error:
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lexiWarn)

                Text("本段翻译失败")
                    .font(LexiFont.zh(12.5))
                    .foregroundStyle(Color.lexiInk3)

                Button("重试本段", action: retry)
                    .font(LexiFont.sans(11.5))
                    .foregroundStyle(Color.lexiInk2)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.lexiRule2, lineWidth: 1)
                    }
            }
        }
    }
}
