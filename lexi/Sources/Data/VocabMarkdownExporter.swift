import Foundation

nonisolated enum VocabMarkdownExporter {
    static func markdown(
        entries: [VocabEntry],
        bookTitles: [String: String],
        filterDescription: String,
        exportedAt: Date = .init(),
        calendar: Calendar = .current
    ) -> String {
        var lines: [String] = [
            "# Lexi 生词本",
            "",
            "> 导出时间：\(timestamp(exportedAt))  ",
            "> 共 \(entries.count) 条 · 筛选条件：\(filterDescription)",
            "",
            "---",
            "",
        ]

        for entry in entries {
            let ipa = entry.usIPA ?? entry.ukIPA
            let title = [entry.word, ipa].compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }.joined(separator: " ")
            lines.append("## \(title)")
            lines.append("")
            lines.append("- **释义**：\(entry.primaryZh.isEmpty ? "（需重查）" : entry.primaryZh)")
            lines.append("- 语境：\(emptyFallback(entry.context))")
            lines.append("- 来源：\(source(for: entry, bookTitles: bookTitles)) · \(date(entry.addedAt))")
            lines.append("- 状态：\(status(for: entry))")
            lines.append("")
            lines.append("---")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private static func source(for entry: VocabEntry, bookTitles: [String: String]) -> String {
        guard let bookId = entry.seenInBookIds.first else {
            return "MenuBar"
        }
        return bookTitles[bookId] ?? bookId
    }

    private static func emptyFallback(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "（无）"
        }
        return value
    }

    private static func status(for entry: VocabEntry) -> String {
        if entry.mastered {
            if let masteredAt = entry.masteredAt {
                return "已掌握 (\(date(masteredAt)))"
            }
            return "已掌握"
        }
        return "未掌握"
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
