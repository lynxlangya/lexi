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

    func testSavedParagraphRejectsNegativeAndNaNValues() {
        let chapters = makeChapters()

        for rawValue in [-1, Double.nan] {
            let progress = ProgressRecord(
                bookId: "book",
                chapterIdx: 1,
                scrollPct: rawValue,
                updatedAt: Date(lexiTimestamp: 1_800_000_000)
            )

            let target = ReaderResumeTarget.resolve(
                continueReading: true,
                progress: progress,
                chapters: chapters
            )

            XCTAssertEqual(target, ReaderResumeTarget(chapterIndex: 1, paragraphIndex: nil))
        }
    }

    func testFlushPrefersVisibleParagraphOverCachedFallbacks() {
        let index = ReaderScrollProgressResolver.preferredParagraphIndex(
            visibleIndex: 4,
            lastKnownIndex: 8,
            pendingIndex: 7,
            paragraphCount: 12
        )

        XCTAssertEqual(index, 4)
    }

    func testFlushUsesLastKnownParagraphWhenVisibleParagraphIsTemporarilyMissing() {
        let index = ReaderScrollProgressResolver.preferredParagraphIndex(
            visibleIndex: nil,
            lastKnownIndex: 8,
            pendingIndex: nil,
            paragraphCount: 12
        )

        XCTAssertEqual(index, 8)
    }

    func testFlushUsesPendingRestoreTargetBeforeScrollViewReportsVisibleParagraph() {
        let index = ReaderScrollProgressResolver.preferredParagraphIndex(
            visibleIndex: nil,
            lastKnownIndex: nil,
            pendingIndex: 7,
            paragraphCount: 12
        )

        XCTAssertEqual(index, 7)
    }

    func testManualChapterWithoutKnownParagraphStartsAtTop() {
        let index = ReaderScrollProgressResolver.preferredParagraphIndex(
            visibleIndex: nil,
            lastKnownIndex: nil,
            pendingIndex: nil,
            paragraphCount: 12
        )

        XCTAssertEqual(index, 0)
    }

    func testInvalidFallbackIndexesAreIgnored() {
        let index = ReaderScrollProgressResolver.preferredParagraphIndex(
            visibleIndex: 50,
            lastKnownIndex: -2,
            pendingIndex: 3,
            paragraphCount: 5
        )

        XCTAssertEqual(index, 3)
    }

    func testReaderReentryKeepsKnownParagraphAsRestoreTarget() {
        let index = ReaderScrollProgressResolver.bestKnownParagraphIndex(
            visibleIndex: 4,
            lastKnownIndex: 8,
            pendingIndex: nil,
            paragraphCount: 12
        )

        XCTAssertEqual(index, 4)
    }

    func testReaderReentrySkipsRestoreWhenNoParagraphIsKnown() {
        let index = ReaderScrollProgressResolver.bestKnownParagraphIndex(
            visibleIndex: nil,
            lastKnownIndex: nil,
            pendingIndex: nil,
            paragraphCount: 12
        )

        XCTAssertNil(index)
    }

    func testVisibleParagraphResolverChoosesNearestParagraphAtReaderTop() {
        let id = ReaderVisibleParagraphResolver.visibleParagraphId(
            offsets: [
                10: -180,
                11: 24,
                12: 180,
            ],
            paragraphIds: [10, 11, 12]
        )

        XCTAssertEqual(id, 11)
    }

    func testVisibleParagraphResolverFallsBackToFirstPositiveParagraphNearTop() {
        let id = ReaderVisibleParagraphResolver.visibleParagraphId(
            offsets: [
                10: 120,
                11: 320,
            ],
            paragraphIds: [10, 11]
        )

        XCTAssertEqual(id, 10)
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
