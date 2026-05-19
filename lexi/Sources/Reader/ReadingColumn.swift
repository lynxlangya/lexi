import SwiftUI

struct ReadingColumn: View {
    let chapter: DemoChapter
    let fontSize: Double

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ChapterHeader(chapter: chapter)
                    .padding(.bottom, 32)

                ForEach(chapter.paras) { paragraph in
                    ParaView(paragraph: paragraph, fontSize: fontSize)
                }
            }
            .frame(maxWidth: LexiSpacing.contentMax, alignment: .leading)
            .padding(.top, 56)
            .padding(.horizontal, LexiSpacing.windowPad)
            .padding(.bottom, 96)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.automatic)
    }
}
