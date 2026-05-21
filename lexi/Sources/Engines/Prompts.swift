import Foundation

nonisolated enum Prompts {
    static let translationSystem = """
    你是 Lexi 的英文到中文翻译引擎。默认把英文文学段落译成自然、克制、可阅读的中文。
    要求：信、达、雅；保留原文标点节奏；不添加译者按语、解释、脚注或寒暄。
    如果收到 Lexi 单词查询请求，输出精炼的英汉词典义项。
    只输出结果正文。
    """

    private static let wordLookupPrefix = "__LEXI_WORD_LOOKUP__:"

    static func wordLookupPayload(word: String) -> String {
        "\(wordLookupPrefix)\(word)"
    }

    static func translationUserPrompt(paragraph: String) -> String {
        if paragraph.hasPrefix(wordLookupPrefix) {
            let word = String(paragraph.dropFirst(wordLookupPrefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return """
            请作为英汉词典解释这个英文词，输出 2 到 4 条最常用、最合理的中文义项。

            格式要求：
            v. 中文义项；中文义项
            n. 中文义项；中文义项
            web. 中文义项；中文义项

            规则：
            - 第一行放最常用译法。
            - 没有某个词性时可以省略，不要硬凑。
            - 不要编号，不要 Markdown，不要例句，不要解释格式。
            - 只输出义项行。

            英文词：\(word)
            """
        }

        return """
        请翻译下面这个英文段落：

        \(paragraph)
        """
    }
}
