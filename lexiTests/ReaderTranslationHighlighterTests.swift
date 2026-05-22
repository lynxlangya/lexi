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

    func testHighlightsTranslatedPhraseBySentencePosition() {
        let source = """
        After a few hours of using generative AI systems, there will come a moment when you realize that Large Language Models (LLMs), the new form of AI that powers services like ChatGPT, don't act like you expect a computer to act. Instead, they act more like a person. It dawns on you that you are interacting with something new, something alien, and that things are about to change. You stay up, equal parts excited and nervous, wondering: What will my job be like?
        """
        let translated = """
        使用生成式AI系统几个小时后，你会突然意识到，驱动ChatGPT这类服务的新型AI——大型语言模型（LLM）——并不像你预期中电脑该有的样子运作。相反，它们表现得更像一个人。这时你恍然大悟：你正在与某种全新的、陌生的东西互动，而世界即将改变。你彻夜难眠，兴奋与紧张各半，思索着：我的工作会变成什么样？
        """

        let range = ReaderTranslationHighlighter.targetRange(
            sourceText: source,
            selectedText: "You stay up",
            translatedText: translated
        )

        XCTAssertEqual(range.map { String(translated[$0]) }, "你彻夜难眠")
    }
}
