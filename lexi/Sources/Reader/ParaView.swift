import SwiftUI

struct ParaView: View {
    let paragraph: ReaderParagraph
    let fontSize: Double
    let state: ParagraphTranslationState
    let transMode: ReaderTranslationMode
    let preferences: ReaderRuntimePreferences
    let onSelectionChange: (SelectedTextContext?) -> Void
    let retry: () -> Void

    private var enSize: CGFloat {
        CGFloat(fontSize)
    }

    private var zhSize: CGFloat {
        CGFloat(fontSize * 13.5 / 17.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LexiSpacing.enZhGap) {
            if transMode != .zh {
                SelectableReaderText(
                    text: paragraph.en,
                    font: preferences.font.nsSerif(enSize),
                    lineSpacing: enSize * preferences.lineHeight.englishSpacingRatio,
                    foregroundColor: preferences.theme.ink,
                    selectionColor: preferences.accent.primary.opacity(0.28),
                    selectionContext: {
                        SentenceContext(fullSentence: paragraph.en)
                    },
                    onSelectionChange: onSelectionChange
                )
            }

            if transMode != .en {
                translation
            }
        }
        .tint(preferences.accent.primary)
        .padding(.bottom, LexiSpacing.paraGap)
    }

    @ViewBuilder
    private var translation: some View {
        switch state {
        case .cached(let zh):
            translatedText(zh)
        case .translating:
            ShimmerLines(fontSize: zhSize, theme: preferences.theme)
        case .error:
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.lexiWarn)

                Text("本段翻译失败")
                    .font(LexiFont.zh(12.5))
                    .foregroundStyle(preferences.theme.ink3)

                Button("重试本段", action: retry)
                    .font(LexiFont.sans(11.5))
                    .foregroundStyle(preferences.theme.ink2)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(preferences.theme.rule2, lineWidth: 1)
                    }
            }
        }
    }

    @ViewBuilder
    private func translatedText(_ zh: String) -> some View {
        switch preferences.translationStyle {
        case .demote:
            selectableTranslation(zh)
        case .rule:
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(preferences.accent.primary.opacity(0.45))
                    .frame(width: 3)
                selectableTranslation(zh)
            }
        case .tint:
            selectableTranslation(zh)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(preferences.accent.faint)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private func selectableTranslation(_ zh: String) -> some View {
        SelectableReaderText(
            text: zh,
            font: LexiFont.nsSans(zhSize),
            lineSpacing: zhSize * preferences.lineHeight.chineseSpacingRatio,
            foregroundColor: preferences.theme.ink2,
            selectionColor: preferences.accent.primary.opacity(0.28),
            selectionContext: {
                SentenceContext(fullSentence: paragraph.en)
            },
            onSelectionChange: onSelectionChange
        )
    }
}
