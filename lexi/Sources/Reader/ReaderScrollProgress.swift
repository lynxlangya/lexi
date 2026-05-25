import Foundation

struct ScrollPersistenceContext: Sendable {
    let database: AppDatabase
    let bookId: String
    let chapterIndex: Int
    let paragraphIndex: Int
    let bookProgress: Double
}

struct ReaderResumeTarget: Equatable, Sendable {
    let chapterIndex: Int
    let paragraphIndex: Int?

    static func resolve(
        continueReading: Bool,
        progress: ProgressRecord?,
        chapters: [ReaderChapter]
    ) -> ReaderResumeTarget {
        guard continueReading,
              let progress,
              chapters.indices.contains(progress.chapterIdx) else {
            return ReaderResumeTarget(chapterIndex: 0, paragraphIndex: nil)
        }

        let paragraphIndex = ReaderScrollProgressResolver.validParagraphIndex(
            from: progress.scrollPct,
            paragraphCount: chapters[progress.chapterIdx].paragraphs.count
        )
        return ReaderResumeTarget(chapterIndex: progress.chapterIdx, paragraphIndex: paragraphIndex)
    }
}

struct ReaderScrollProgressResolver {
    static func validParagraphIndex(from rawValue: Double, paragraphCount: Int) -> Int? {
        guard rawValue.isFinite, rawValue >= 0 else {
            return nil
        }

        let index = Int(rawValue)
        guard (0..<paragraphCount).contains(index) else {
            return nil
        }

        return index
    }

    static func preferredParagraphIndex(
        visibleIndex: Int?,
        lastKnownIndex: Int?,
        pendingIndex: Int?,
        paragraphCount: Int
    ) -> Int {
        bestKnownParagraphIndex(
            visibleIndex: visibleIndex,
            lastKnownIndex: lastKnownIndex,
            pendingIndex: pendingIndex,
            paragraphCount: paragraphCount
        ) ?? 0
    }

    static func bestKnownParagraphIndex(
        visibleIndex: Int?,
        lastKnownIndex: Int?,
        pendingIndex: Int?,
        paragraphCount: Int
    ) -> Int? {
        guard paragraphCount > 0 else {
            return nil
        }

        for candidate in [visibleIndex, lastKnownIndex, pendingIndex] {
            guard let candidate, (0..<paragraphCount).contains(candidate) else {
                continue
            }
            return candidate
        }

        return nil
    }
}
