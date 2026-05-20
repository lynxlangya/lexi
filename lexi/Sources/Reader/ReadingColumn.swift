import SwiftUI

struct ReadingColumn: View {
    let chapter: ReaderChapter
    let fontSize: Double
    let snapshot: ChapterTranslationSnapshot
    let transMode: ReaderTranslationMode
    let preferences: ReaderRuntimePreferences
    let retryParagraph: (ReaderParagraph) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ChapterHeader(chapter: chapter, preferences: preferences)
                    .padding(.bottom, 32)

                ForEach(chapter.paragraphs) { paragraph in
                    ParaView(
                        paragraph: paragraph,
                        fontSize: fontSize,
                        state: snapshot.paragraphStates[paragraph.id] ?? .translating,
                        transMode: transMode,
                        preferences: preferences
                    ) {
                        retryParagraph(paragraph)
                    }
                }
            }
            .frame(maxWidth: LexiSpacing.contentMax, alignment: .leading)
            .frame(maxWidth: .infinity)
            .background(ReaderScrollViewStyler(preferences: preferences))
            .padding(.top, 56)
            .padding(.horizontal, LexiSpacing.windowPad)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.automatic)
        .background(preferences.theme.paper)
    }
}
