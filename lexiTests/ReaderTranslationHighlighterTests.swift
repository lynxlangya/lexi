import XCTest
@testable import lexi

final class ReaderTranslationHighlighterTests: XCTestCase {
    func testHighlightsChineseTermForParenthesizedAcronymSelection() {
        let source = "Large Language Models (LLMs), the new form of AI, power services like ChatGPT."
        let translated = "大型语言模型（LLM）是驱动 ChatGPT 这类服务的新型 AI。"

        let range = ReaderTranslationHighlighter.targetRange(
            sourceText: source,
            selectedText: "Large Language Models (LLMs)",
            translatedText: translated
        )

        XCTAssertEqual(range.map { String(translated[$0]) }, "大型语言模型（LLM）")
    }

    func testHighlightsNearbyChineseTermForAcronymSelection() {
        let source = "The LLM can explain the concept."
        let translated = "这个大型语言模型（LLM）可以解释这个概念。"

        let range = ReaderTranslationHighlighter.targetRange(
            sourceText: source,
            selectedText: "LLM",
            translatedText: translated
        )

        XCTAssertEqual(range.map { String(translated[$0]) }, "大型语言模型（LLM）")
    }

    func testHighlightsTranslatedSentenceForLongSentenceSelection() {
        let source = "The tool is useful. It helps readers compare English and Chinese quickly. Another idea follows."
        let translated = "这个工具很有用。它帮助读者快速对照英文和中文。后面还有另一个想法。"

        let range = ReaderTranslationHighlighter.targetRange(
            sourceText: source,
            selectedText: "It helps readers compare English and Chinese quickly.",
            translatedText: translated
        )

        XCTAssertEqual(range.map { String(translated[$0]) }, "它帮助读者快速对照英文和中文。")
    }

    func testReturnsNilForLowConfidencePhrase() {
        let range = ReaderTranslationHighlighter.targetRange(
            sourceText: "This is a difficult idiom.",
            selectedText: "difficult idiom",
            translatedText: "这句话被意译了。"
        )

        XCTAssertNil(range)
    }
}
