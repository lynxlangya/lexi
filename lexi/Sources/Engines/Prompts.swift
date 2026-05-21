import Foundation

nonisolated enum Prompts {
    static let translationSystem = """
    你是 Lexi 的英文到中文翻译引擎。默认把英文文学段落译成自然、克制、可阅读的中文。
    要求：信、达、雅；保留原文标点节奏；不添加译者按语、解释、脚注或寒暄。
    如果收到 Lexi 单词查询请求，输出精炼的英汉词典义项。
    只输出结果正文。
    """

    static func translationUserPrompt(for task: TranslationTask) -> String {
        switch task {
        case .paragraph(let text, _):
            return """
            请翻译下面这个英文段落：

            \(text)
            """
        case .sentence(let text, let context):
            let sentence = context?.fullSentence.flatMap { $0.isEmpty ? nil : $0 }
            return """
            请翻译下面这个英文句子：

            \(text)
            \(sentence.map { "\n完整上下文句：\($0)" } ?? "")
            """
        case .wordLookup(let word, let context):
            let sentence = context?.fullSentence.flatMap { $0.isEmpty ? nil : $0 }
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
            \(sentence.map { "完整上下文句：\($0)" } ?? "")
            """
        case .phraseLookup(let phrase, let context):
            let sentence = context?.fullSentence.flatMap { $0.isEmpty ? nil : $0 }
            return """
            请解释下面这个英文短语在语境中的中文含义，输出 2 到 4 条最合理的中文释义。

            英文短语：\(phrase)
            \(sentence.map { "完整上下文句：\($0)" } ?? "")
            """
        }
    }

    static func translationUserPrompt(paragraph: String) -> String {
        return """
        请翻译下面这个英文段落：

        \(paragraph)
        """
    }
}
