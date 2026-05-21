import XCTest
@testable import lexi

final class PromptsTests: XCTestCase {
    func testTaskSpecificSystemPromptsContainRequiredSections() {
        let prompts = [
            Prompts.paragraphTranslationSystem,
            Prompts.sentenceTranslationSystem,
            Prompts.wordLookupSystem,
            Prompts.phraseLookupSystem,
        ]

        for prompt in prompts {
            XCTAssertTrue(prompt.contains("Role:"))
            XCTAssertTrue(prompt.contains("Output language lock:"))
            XCTAssertTrue(prompt.contains("Register guideline:"))
            XCTAssertTrue(prompt.contains("Task-specific formatting rules:"))
            XCTAssertTrue(prompt.contains("Hard constraints:"))
        }
    }

    func testSystemPromptsAreEnglishAndDoNotContainLegacyChineseInstructions() {
        let combined = [
            Prompts.paragraphTranslationSystem,
            Prompts.sentenceTranslationSystem,
            Prompts.wordLookupSystem,
            Prompts.phraseLookupSystem,
        ].joined(separator: "\n")

        XCTAssertFalse(combined.contains("你是"))
        XCTAssertFalse(combined.contains("请翻译"))
        XCTAssertFalse(combined.contains("请作为英汉词典"))
    }

    func testSystemPromptDispatchesByTaskType() {
        XCTAssertEqual(
            Prompts.systemPrompt(for: .paragraph(text: "Text", context: ParagraphContext())),
            Prompts.paragraphTranslationSystem
        )
        XCTAssertEqual(
            Prompts.systemPrompt(for: .sentence(text: "Text", context: nil)),
            Prompts.sentenceTranslationSystem
        )
        XCTAssertEqual(
            Prompts.systemPrompt(for: .wordLookup(word: "observe", context: nil)),
            Prompts.wordLookupSystem
        )
        XCTAssertEqual(
            Prompts.systemPrompt(for: .phraseLookup(phrase: "look up", context: nil)),
            Prompts.phraseLookupSystem
        )
    }

    func testUserPromptsKeepChineseGuidance() {
        let paragraphPrompt = Prompts.userPrompt(
            for: .paragraph(text: "He waited.", context: ParagraphContext())
        )
        let sentencePrompt = Prompts.userPrompt(
            for: .sentence(text: "He waited.", context: SentenceContext(fullSentence: "He waited at the door."))
        )

        XCTAssertTrue(paragraphPrompt.contains("把下面这段英文译成中文"))
        XCTAssertTrue(sentencePrompt.contains("把下面这个英文句子译成中文"))
        XCTAssertTrue(sentencePrompt.contains("完整上下文句：He waited at the door."))
    }
}
