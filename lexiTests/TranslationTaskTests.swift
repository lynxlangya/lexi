import XCTest
@testable import lexi

final class TranslationTaskTests: XCTestCase {
    func testWordLookupPromptUsesExplicitTaskInsteadOfSentinelPrefix() {
        let prompt = Prompts.userPrompt(
            for: .wordLookup(
                word: "observe",
                context: SentenceContext(fullSentence: "They observe the Sabbath.", bookTitle: nil)
            )
        )

        XCTAssertFalse(prompt.contains("__LEXI_WORD_LOOKUP__:"))
        XCTAssertTrue(prompt.contains("英文词：observe"))
        XCTAssertTrue(prompt.contains("完整上下文句：They observe the Sabbath."))
    }

    func testParagraphTaskCarriesContextWithoutChangingSourceText() {
        let task = TranslationTask.paragraph(
            text: "He looked at the green light.",
            context: ParagraphContext(bookTitle: "The Great Gatsby", chapterTitle: "Chapter I")
        )

        guard case .paragraph(let text, let context) = task else {
            return XCTFail("Expected paragraph task")
        }

        XCTAssertEqual(text, "He looked at the green light.")
        XCTAssertEqual(context.bookTitle, "The Great Gatsby")
        XCTAssertEqual(context.chapterTitle, "Chapter I")
    }
}
