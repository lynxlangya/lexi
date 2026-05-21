import XCTest
@testable import lexi

final class ReaderAddWordShortcutTests: XCTestCase {
    func testReaderAddWordCandidateAcceptsSingleWordAndKeepsSentenceContext() {
        let context = SelectedTextContext(
            text: " observe ",
            anchor: .zero,
            source: .reader,
            sentenceContext: SentenceContext(fullSentence: "They observe quietly.", bookTitle: "Co-Intelligence")
        )

        let candidate = ReaderAddWordCandidate(context: context)

        XCTAssertEqual(candidate?.word, "observe")
        XCTAssertEqual(candidate?.sentenceContext?.fullSentence, "They observe quietly.")
        XCTAssertEqual(candidate?.sentenceContext?.bookTitle, "Co-Intelligence")
    }

    func testReaderAddWordCandidateRejectsPhrasesAndNonWords() {
        XCTAssertNil(
            ReaderAddWordCandidate(
                context: SelectedTextContext(text: "two words", anchor: .zero, source: .reader)
            )
        )
        XCTAssertNil(
            ReaderAddWordCandidate(
                context: SelectedTextContext(text: "42%", anchor: .zero, source: .reader)
            )
        )
    }
}
