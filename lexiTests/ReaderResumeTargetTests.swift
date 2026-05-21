import XCTest
@testable import lexi

final class ReaderResumeTargetTests: XCTestCase {
    func testClickingReadBookResolvesSavedChapterAndParagraph() {
        let chapters = makeChapters()
        let progress = ProgressRecord(
            bookId: "book",
            chapterIdx: 1,
            scrollPct: 2,
            updatedAt: Date(lexiTimestamp: 1_800_000_000)
        )

        let target = ReaderResumeTarget.resolve(
            continueReading: true,
            progress: progress,
            chapters: chapters
        )

        XCTAssertEqual(target, ReaderResumeTarget(chapterIndex: 1, paragraphIndex: 2))
    }

    func testUnreadBookStartsAtBeginningInsteadOfReusingPreviousChapter() {
        let target = ReaderResumeTarget.resolve(
            continueReading: true,
            progress: nil,
            chapters: makeChapters()
        )

        XCTAssertEqual(target, ReaderResumeTarget(chapterIndex: 0, paragraphIndex: nil))
    }

    func testExplicitOpenFromBeginningIgnoresSavedProgress() {
        let chapters = makeChapters()
        let progress = ProgressRecord(
            bookId: "book",
            chapterIdx: 1,
            scrollPct: 2,
            updatedAt: Date(lexiTimestamp: 1_800_000_000)
        )

        let target = ReaderResumeTarget.resolve(
            continueReading: false,
            progress: progress,
            chapters: chapters
        )

        XCTAssertEqual(target, ReaderResumeTarget(chapterIndex: 0, paragraphIndex: nil))
    }

    func testInvalidSavedParagraphStillRestoresSavedChapter() {
        let chapters = makeChapters()
        let progress = ProgressRecord(
            bookId: "book",
            chapterIdx: 1,
            scrollPct: 200,
            updatedAt: Date(lexiTimestamp: 1_800_000_000)
        )

        let target = ReaderResumeTarget.resolve(
            continueReading: true,
            progress: progress,
            chapters: chapters
        )

        XCTAssertEqual(target, ReaderResumeTarget(chapterIndex: 1, paragraphIndex: nil))
    }

    private func makeChapters() -> [ReaderChapter] {
        [
            ReaderChapter(
                id: 10,
                bookId: "book",
                idx: 0,
                n: "1",
                title: "One",
                paragraphs: makeParagraphs(chapterOffset: 10)
            ),
            ReaderChapter(
                id: 20,
                bookId: "book",
                idx: 1,
                n: "2",
                title: "Two",
                paragraphs: makeParagraphs(chapterOffset: 20)
            ),
        ]
    }

    private func makeParagraphs(chapterOffset: Int64) -> [ReaderParagraph] {
        (0..<3).map { index in
            ReaderParagraph(
                id: chapterOffset + Int64(index),
                ord: index,
                en: "Paragraph \(index)"
            )
        }
    }
}
