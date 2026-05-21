import SwiftUI

struct ReadingColumn: View {
    let chapter: ReaderChapter
    let previousChapter: ReaderChapter?
    let nextChapter: ReaderChapter?
    let fontSize: Double
    let snapshot: ChapterTranslationSnapshot
    let transMode: ReaderTranslationMode
    let preferences: ReaderRuntimePreferences
    @Binding var visibleParagraphId: Int64?
    @Binding var selectedTextContext: SelectedTextContext?
    let goToPreviousChapter: () -> Void
    let goToNextChapter: () -> Void
    let onParagraphChange: (Int64) -> Void
    let retryParagraph: (ReaderParagraph) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ChapterHeader(chapter: chapter, preferences: preferences)
                    .padding(.bottom, 32)

                ForEach(chapter.paragraphs) { paragraph in
                    ParaView(
                        paragraph: paragraph,
                        fontSize: fontSize,
                        state: snapshot.paragraphStates[paragraph.id] ?? .translating,
                        transMode: transMode,
                        preferences: preferences,
                        onSelectionChange: { context in
                            selectedTextContext = context.map {
                                SelectedTextContext(
                                    text: $0.text,
                                    anchor: $0.anchor,
                                    source: .reader,
                                    sentenceContext: SentenceContext(
                                        fullSentence: paragraph.en,
                                        bookTitle: chapter.title
                                    )
                                )
                            }
                        }
                    ) {
                        retryParagraph(paragraph)
                    }
                    .id(paragraph.id)
                }

                EndOfChapterNavigation(
                    previousChapter: previousChapter,
                    nextChapter: nextChapter,
                    preferences: preferences,
                    goToPreviousChapter: goToPreviousChapter,
                    goToNextChapter: goToNextChapter
                )
            }
            .frame(maxWidth: LexiSpacing.contentMax, alignment: .leading)
            .frame(maxWidth: .infinity)
            .background(ReaderScrollViewStyler(preferences: preferences))
            .padding(.top, 56)
            .padding(.horizontal, LexiSpacing.windowPad)
            .padding(.bottom, 96)
        }
        .id(chapter.id)
        .scrollPosition(id: $visibleParagraphId, anchor: .top)
        .scrollIndicators(.automatic)
        .background(preferences.theme.paper)
        .tint(preferences.accent.primary)
        .onChange(of: visibleParagraphId) { _, nextId in
            guard let nextId,
                  chapter.paragraphs.contains(where: { $0.id == nextId }) else {
                return
            }
            onParagraphChange(nextId)
        }
    }
}

private struct EndOfChapterNavigation: View {
    let previousChapter: ReaderChapter?
    let nextChapter: ReaderChapter?
    let preferences: ReaderRuntimePreferences
    let goToPreviousChapter: () -> Void
    let goToNextChapter: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Button {
                goToPreviousChapter()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("上一章")
                        .font(LexiFont.zh(12.5))
                }
                .foregroundStyle(previousChapter == nil ? preferences.theme.ink4 : preferences.theme.ink2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(previousChapter == nil)
            .help(previousChapter == nil ? "已经是第一章" : "上一章")

            Spacer(minLength: 24)

            Button {
                goToNextChapter()
            } label: {
                HStack(spacing: 7) {
                    Text(nextTitle)
                        .font(LexiFont.zh(12.5))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(nextChapter == nil ? preferences.theme.ink4 : preferences.accent.primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(nextChapter == nil)
            .help(nextChapter == nil ? "已经是最后一章" : "下一章")
        }
        .padding(.top, 24)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(preferences.theme.rule)
                .frame(height: 1)
        }
        .padding(.top, 48)
    }

    private var nextTitle: String {
        guard let nextChapter else {
            return "下一章"
        }

        return "下一章 · \(truncated(nextChapter.title))"
    }

    private func truncated(_ title: String) -> String {
        let maxLength = 28
        guard title.count > maxLength else {
            return title
        }

        return "\(title.prefix(maxLength))..."
    }
}
