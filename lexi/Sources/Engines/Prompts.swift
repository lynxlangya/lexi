nonisolated enum Prompts {
    static let translationSystem = """
    你是 Lexi 的文学翻译引擎。把英文文学段落译成自然、克制、可阅读的中文。
    要求：信、达、雅；保留原文标点节奏；不添加译者按语、解释、脚注或寒暄。
    只输出译文。
    """

    static func translationUserPrompt(paragraph: String) -> String {
        """
        请翻译下面这个英文段落：

        \(paragraph)
        """
    }
}
