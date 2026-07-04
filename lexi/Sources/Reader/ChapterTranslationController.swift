import Foundation
import Observation

private let paragraphTranslationMaxAttempts = 2
private nonisolated let paragraphStreamingFlushInterval: Duration = .milliseconds(66)
private let defaultParagraphRetryDelayNanoseconds: UInt64 = 1_500_000_000
private let overloadedParagraphRetryDelayNanoseconds: UInt64 = 4_000_000_000

enum ChapterTranslationState: Equatable, Sendable {
    case idle
    case translating(done: Int)
    case cached
    case error(String)

    var done: Int {
        switch self {
        case .idle:
            return 0
        case .translating(let done):
            return done
        case .cached:
            return .max
        case .error:
            return 0
        }
    }
}

enum ParagraphTranslationState: Equatable, Sendable {
    case cached(String)
    case streaming(String)
    case translating
    case error(String)
}

struct ChapterTranslationSnapshot: Equatable, Sendable {
    var chapterState: ChapterTranslationState = .idle
    var paragraphStates: [Int64: ParagraphTranslationState] = [:]
}

@Observable
@MainActor
final class ChapterTranslationController {
    private let database: AppDatabase
    private let registry: EngineRegistry
    private let prefetchWorker: ChapterPrefetchWorker
    private let streamClockNow: @Sendable () -> ContinuousClock.Instant
    private let streamFlushInterval: Duration
    private let retrySleep: @Sendable (UInt64) async throws -> Void
    private var task: Task<Void, Never>?
    private var paragraphRetryTasks: [Int64: Task<Void, Never>] = [:]
    private var paragraphRetryTokens: [Int64: UUID] = [:]

    private(set) var selectedChapterId: Int64?
    private(set) var currentEngineConfig: EngineConfig
    private(set) var snapshots: [Int64: ChapterTranslationSnapshot] = [:]

    init(
        database: AppDatabase,
        engineConfig: EngineConfig,
        registry: EngineRegistry = .shared,
        streamClockNow: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now },
        streamFlushInterval: Duration = paragraphStreamingFlushInterval,
        retrySleep: @escaping @Sendable (UInt64) async throws -> Void = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.database = database
        self.currentEngineConfig = engineConfig
        self.registry = registry
        self.prefetchWorker = ChapterPrefetchWorker(database: database, registry: registry)
        self.streamClockNow = streamClockNow
        self.streamFlushInterval = streamFlushInterval
        self.retrySleep = retrySleep
    }

    @MainActor deinit {
        task?.cancel()
        cancelParagraphRetryTasks()
    }

    var engineLabel: String {
        currentEngineConfig.displayName
    }

    func prepare(chapters: [ReaderChapter]) async {
        for chapter in chapters {
            do {
                let snapshot = try await cachedSnapshot(
                    for: chapter,
                    database: database,
                    config: currentEngineConfig
                )
                snapshots[chapter.id] = snapshot
                reconcileChapterState(for: chapter)
            } catch {
                snapshots[chapter.id] = ChapterTranslationSnapshot(chapterState: .error(error.localizedDescription))
            }
        }
    }

    func selectChapter(
        _ chapter: ReaderChapter,
        chapters: [ReaderChapter],
        prefetchCount: Int,
        bookTitle: String? = nil
    ) {
        task?.cancel()
        cancelParagraphRetryTasks()
        selectedChapterId = chapter.id
        task = Task { [database, registry, currentEngineConfig] in
            await translateChapter(
                chapter,
                database: database,
                registry: registry,
                config: currentEngineConfig,
                bookTitle: bookTitle
            )

            guard !Task.isCancelled, prefetchCount > 0 else {
                return
            }

            let nextChapters = chapters
                .filter { $0.idx > chapter.idx }
                .prefix(prefetchCount)
            for nextChapter in nextChapters {
                await prefetchWorker.prefetch(chapter: nextChapter, config: currentEngineConfig, bookTitle: bookTitle)
            }
        }
    }

    func retryParagraph(_ paragraph: ReaderParagraph, in chapter: ReaderChapter, bookTitle: String? = nil) {
        paragraphRetryTasks[paragraph.id]?.cancel()
        let token = UUID()
        paragraphRetryTokens[paragraph.id] = token
        paragraphRetryTasks[paragraph.id] = Task { [database, registry, currentEngineConfig] in
            await translateParagraph(
                paragraph,
                in: chapter,
                database: database,
                registry: registry,
                config: currentEngineConfig,
                bookTitle: bookTitle
            )
            if paragraphRetryTokens[paragraph.id] == token {
                paragraphRetryTasks[paragraph.id] = nil
                paragraphRetryTokens[paragraph.id] = nil
            }
        }
    }

    func switchEngine(
        _ config: EngineConfig,
        chapter: ReaderChapter,
        chapters: [ReaderChapter],
        prefetchCount: Int,
        bookTitle: String? = nil
    ) {
        currentEngineConfig = config
        selectChapter(chapter, chapters: chapters, prefetchCount: prefetchCount, bookTitle: bookTitle)
    }

    func snapshot(for chapterId: Int64) -> ChapterTranslationSnapshot {
        snapshots[chapterId] ?? ChapterTranslationSnapshot()
    }

    func chapterState(for chapterId: Int64) -> ChapterTranslationState {
        snapshot(for: chapterId).chapterState
    }

    func paragraphState(for paragraph: ReaderParagraph, in chapterId: Int64) -> ParagraphTranslationState {
        snapshot(for: chapterId).paragraphStates[paragraph.id] ?? .translating
    }

    private func translateChapter(
        _ chapter: ReaderChapter,
        database: AppDatabase,
        registry: EngineRegistry,
        config: EngineConfig,
        bookTitle: String?
    ) async {
        var missing: [ReaderParagraph] = []
        do {
            let snapshot = try await cachedSnapshot(for: chapter, database: database, config: config)
            var exactCached = try await database.cachedTranslations(
                chapterId: chapter.id,
                engine: config.id,
                model: config.model
            )
            exactCached = completeCachedTranslations(exactCached, in: chapter)
            let cachedCount = chapter.paragraphs.filter { paragraph in
                if case .cached = snapshot.paragraphStates[paragraph.id] {
                    return true
                }
                return false
            }.count

            if cachedCount == chapter.paragraphs.count {
                snapshots[chapter.id] = snapshot
                reconcileChapterState(for: chapter)
                return
            }

            snapshots[chapter.id] = snapshot

            missing = chapter.paragraphs.filter { paragraph in
                if case .cached = snapshot.paragraphStates[paragraph.id] {
                    return false
                }
                return true
            }
            missing.forEach { paragraph in
                snapshots[chapter.id]?.paragraphStates[paragraph.id] = .translating
            }
            reconcileChapterState(for: chapter)

            let engine = try registry.engine(for: config)
            for (missingIndex, paragraph) in missing.enumerated() {
                if let cachedZH = try await completeCachedTranslation(for: paragraph, database: database, config: config) {
                    snapshots[chapter.id]?.paragraphStates[paragraph.id] = .cached(cachedZH)
                    exactCached[paragraph.id] = cachedZH
                    reconcileChapterState(for: chapter)
                    continue
                }

                let task = TranslationTask.paragraph(
                    text: paragraph.en,
                    context: paragraphContext(
                        for: paragraph,
                        in: chapter,
                        exactCached: exactCached,
                        bookTitle: bookTitle
                    )
                )

                switch await translateParagraphTextWithRetry(
                    task,
                    source: paragraph.en,
                    paragraph: paragraph,
                    chapter: chapter,
                    engine: engine,
                    model: config.model
                ) {
                case .success(let zh):
                    snapshots[chapter.id]?.paragraphStates[paragraph.id] = .cached(zh)
                    reconcileChapterState(for: chapter)
                    do {
                        try await database.upsertTranslation(
                            Translation(
                                id: nil,
                                paragraphId: paragraph.id,
                                engine: config.id,
                                model: config.model,
                                zh: zh,
                                createdAt: Date()
                            )
                        )
                    } catch is CancellationError {
                        return
                    } catch {
                        apply(reason: error.localizedDescription, to: chapter, translating: Array(missing[missingIndex...]))
                        return
                    }
                    exactCached[paragraph.id] = zh
                case .failure(let reason):
                    snapshots[chapter.id]?.paragraphStates[paragraph.id] = .error(reason)
                    reconcileChapterState(for: chapter)
                    continue
                case .cancelled:
                    return
                }
            }

            markTranslatingParagraphsAsError(
                in: chapter,
                candidates: missing,
                reason: "翻译流提前结束，本段未译"
            )
            reconcileChapterState(for: chapter)
        } catch is CancellationError {
            return
        } catch let error as EngineError {
            apply(error: error, to: chapter, translating: missing)
        } catch {
            apply(reason: error.localizedDescription, to: chapter, translating: missing)
        }
    }

    private func translateParagraphTextWithRetry(
        _ task: TranslationTask,
        source: String,
        paragraph: ReaderParagraph,
        chapter: ReaderChapter,
        engine: any TranslationEngine,
        model: String
    ) async -> ParagraphTranslationAttemptResult {
        var lastReason = "翻译失败"
        var retryDelayNanoseconds = defaultParagraphRetryDelayNanoseconds

        for attempt in 1...paragraphTranslationMaxAttempts {
            if attempt > 1 {
                do {
                    try await retrySleep(retryDelayNanoseconds)
                } catch is CancellationError {
                    return .cancelled
                } catch {
                    return .cancelled
                }
            }

            snapshots[chapter.id]?.paragraphStates[paragraph.id] = .translating
            reconcileChapterState(for: chapter)

            do {
                let zh = try await translateParagraphText(
                    task,
                    source: source,
                    paragraph: paragraph,
                    chapter: chapter,
                    engine: engine,
                    model: model
                )
                return .success(zh)
            } catch is CancellationError {
                return .cancelled
            } catch let error as ParagraphTranslationFailure {
                lastReason = error.localizedDescription
                retryDelayNanoseconds = defaultParagraphRetryDelayNanoseconds
            } catch {
                lastReason = paragraphFailureReason(error)
                retryDelayNanoseconds = retryDelay(for: error, reason: lastReason)
            }
        }

        return .failure(lastReason)
    }

    private func translateParagraphText(
        _ task: TranslationTask,
        source: String,
        paragraph: ReaderParagraph,
        chapter: ReaderChapter,
        engine: any TranslationEngine,
        model: String
    ) async throws -> String {
        var zh = ""
        var lastFlush = streamClockNow()
        var didFlushStreamingText = false
        for try await chunk in engine.translate([task], model: model) {
            try Task.checkCancellation()
            zh += chunk.text
            if shouldFlushStreamingText(lastFlush: &lastFlush, didFlush: &didFlushStreamingText) {
                flushStreamingText(zh, paragraph: paragraph, chapter: chapter)
            }
        }
        flushStreamingText(zh, paragraph: paragraph, chapter: chapter)

        if zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ParagraphTranslationFailure.emptyStream
        }
        guard ParagraphTranslationCompleteness.isComplete(source: source, translation: zh) else {
            throw ParagraphTranslationFailure.incomplete
        }
        return zh
    }

    private func paragraphFailureReason(_ error: Error) -> String {
        if let engineError = error as? EngineError {
            switch engineError {
            case .taskFailed(_, let reason):
                return reason
            default:
                return engineError.localizedDescription
            }
        }

        return error.localizedDescription
    }

    private func retryDelay(for error: Error, reason: String) -> UInt64 {
        guard let status = httpStatusCode(from: error, reason: reason),
              status == 429 || (500..<600).contains(status) else {
            return defaultParagraphRetryDelayNanoseconds
        }
        return overloadedParagraphRetryDelayNanoseconds
    }

    private func httpStatusCode(from error: Error, reason: String) -> Int? {
        if let engineError = error as? EngineError {
            switch engineError {
            case .httpStatus(let status, _):
                return status
            case .taskFailed(_, let reason):
                return httpStatusCode(from: reason)
            default:
                break
            }
        }
        return httpStatusCode(from: reason)
    }

    private func httpStatusCode(from reason: String) -> Int? {
        guard let range = reason.range(of: "HTTP ") else {
            return nil
        }
        let suffix = reason[range.upperBound...]
        let digits = suffix.prefix { $0.isWholeNumber }
        return Int(digits)
    }

    private func translateParagraph(
        _ paragraph: ReaderParagraph,
        in chapter: ReaderChapter,
        database: AppDatabase,
        registry: EngineRegistry,
        config: EngineConfig,
        bookTitle: String?
    ) async {
        do {
            snapshots[chapter.id]?.paragraphStates[paragraph.id] = .translating
            reconcileChapterState(for: chapter)
            let engine = try registry.engine(for: config)
            var zh = ""
            let exactCached = try await database.cachedTranslations(
                chapterId: chapter.id,
                engine: config.id,
                model: config.model
            )
            let task = TranslationTask.paragraph(
                text: paragraph.en,
                context: paragraphContext(
                    for: paragraph,
                    in: chapter,
                    exactCached: completeCachedTranslations(exactCached, in: chapter),
                    bookTitle: bookTitle
                )
            )
            var lastFlush = streamClockNow()
            var didFlushStreamingText = false
            for try await chunk in engine.translate([task], model: config.model) {
                try Task.checkCancellation()
                zh += chunk.text
                if shouldFlushStreamingText(lastFlush: &lastFlush, didFlush: &didFlushStreamingText) {
                    flushStreamingText(zh, paragraph: paragraph, chapter: chapter)
                }
            }
            flushStreamingText(zh, paragraph: paragraph, chapter: chapter)

            if zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                markTranslatingParagraphsAsError(
                    in: chapter,
                    candidates: [paragraph],
                    reason: "翻译流提前结束，本段未译"
                )
                reconcileChapterState(for: chapter)
                return
            }
            guard ParagraphTranslationCompleteness.isComplete(source: paragraph.en, translation: zh) else {
                markTranslatingParagraphsAsError(
                    in: chapter,
                    candidates: [paragraph],
                    reason: "翻译结果疑似不完整，本段未缓存"
                )
                reconcileChapterState(for: chapter)
                return
            }

            snapshots[chapter.id]?.paragraphStates[paragraph.id] = .cached(zh)
            reconcileChapterState(for: chapter)
            try await database.upsertTranslation(
                Translation(
                    id: nil,
                    paragraphId: paragraph.id,
                    engine: config.id,
                    model: config.model,
                    zh: zh,
                    createdAt: Date()
                )
            )
        } catch is CancellationError {
            return
        } catch let error as EngineError {
            apply(error: error, to: chapter, translating: [paragraph])
        } catch {
            apply(reason: error.localizedDescription, to: chapter, translating: [paragraph])
        }
    }

    private func cachedSnapshot(
        for chapter: ReaderChapter,
        database: AppDatabase,
        config: EngineConfig
    ) async throws -> ChapterTranslationSnapshot {
        let cached = try await database.cachedTranslations(
            chapterId: chapter.id,
            preferredEngine: config.id,
            preferredModel: config.model
        )
        var snapshot = snapshots[chapter.id] ?? ChapterTranslationSnapshot()
        for paragraph in chapter.paragraphs {
            if let zh = cached[paragraph.id],
               ParagraphTranslationCompleteness.isComplete(source: paragraph.en, translation: zh) {
                snapshot.paragraphStates[paragraph.id] = .cached(zh)
            } else if case .cached = snapshot.paragraphStates[paragraph.id] {
                snapshot.paragraphStates[paragraph.id] = nil
            }
        }
        return snapshot
    }

    private func shouldFlushStreamingText(
        lastFlush: inout ContinuousClock.Instant,
        didFlush: inout Bool
    ) -> Bool {
        guard didFlush else {
            didFlush = true
            lastFlush = streamClockNow()
            return true
        }

        let now = streamClockNow()
        guard lastFlush.duration(to: now) >= streamFlushInterval else {
            return false
        }

        lastFlush = now
        return true
    }

    private func flushStreamingText(
        _ text: String,
        paragraph: ReaderParagraph,
        chapter: ReaderChapter
    ) {
        guard !text.isEmpty else {
            return
        }
        snapshots[chapter.id]?.paragraphStates[paragraph.id] = .streaming(text)
    }

    private func apply(error: EngineError, to chapter: ReaderChapter, translating: [ReaderParagraph]) {
        switch error {
        case .taskFailed(let index, let reason):
            let paragraphs = paragraphsForError(in: chapter, translating: translating)
            if let paragraph = paragraphs[safe: index] {
                snapshots[chapter.id]?.paragraphStates[paragraph.id] = .error(reason)
                markTranslatingParagraphsAsError(
                    in: chapter,
                    candidates: paragraphs,
                    reason: "上游段失败，本段未译",
                    excluding: paragraph.id
                )
                reconcileChapterState(for: chapter)
            } else {
                apply(reason: reason, to: chapter, translating: translating)
            }
        default:
            apply(reason: error.localizedDescription, to: chapter, translating: translating)
        }
    }

    private func apply(reason: String, to chapter: ReaderChapter, translating: [ReaderParagraph]) {
        for paragraph in paragraphsForError(in: chapter, translating: translating) {
            snapshots[chapter.id]?.paragraphStates[paragraph.id] = .error(reason)
        }
        reconcileChapterState(for: chapter)
    }

    private func paragraphsForError(in chapter: ReaderChapter, translating: [ReaderParagraph]) -> [ReaderParagraph] {
        if !translating.isEmpty {
            return translating
        }

        return chapter.paragraphs.filter { paragraph in
            if case .cached = snapshots[chapter.id]?.paragraphStates[paragraph.id] {
                return false
            }
            return true
        }
    }

    private func reconcileChapterState(for chapter: ReaderChapter) {
        guard var snapshot = snapshots[chapter.id] else {
            return
        }

        var cachedCount = 0
        var hasTranslating = false
        var errorReason: String?

        for paragraph in chapter.paragraphs {
            switch snapshot.paragraphStates[paragraph.id] {
            case .cached:
                cachedCount += 1
            case .streaming, .translating:
                hasTranslating = true
            case .error(let reason):
                errorReason = errorReason ?? reason
            case .none:
                break
            }
        }

        if cachedCount == chapter.paragraphs.count {
            snapshot.chapterState = .cached
        } else if let errorReason {
            snapshot.chapterState = .error(errorReason)
        } else if hasTranslating {
            snapshot.chapterState = .translating(done: cachedCount)
        } else {
            snapshot.chapterState = .idle
        }

        snapshots[chapter.id] = snapshot
    }

    private func markTranslatingParagraphsAsError(
        in chapter: ReaderChapter,
        candidates: [ReaderParagraph],
        reason: String,
        excluding excludedParagraphId: Int64? = nil
    ) {
        for paragraph in candidates where paragraph.id != excludedParagraphId {
            switch snapshots[chapter.id]?.paragraphStates[paragraph.id] {
            case .translating, .streaming:
                snapshots[chapter.id]?.paragraphStates[paragraph.id] = .error(reason)
            default:
                break
            }
        }
    }

    private func cancelParagraphRetryTasks() {
        paragraphRetryTasks.values.forEach { $0.cancel() }
        paragraphRetryTasks.removeAll()
        paragraphRetryTokens.removeAll()
    }

    private func paragraphContext(
        for paragraph: ReaderParagraph,
        in chapter: ReaderChapter,
        exactCached: [Int64: String],
        bookTitle: String?
    ) -> ParagraphContext {
        let previousParagraph = chapter.paragraphs.first { $0.ord == paragraph.ord - 1 }
        return ParagraphContext(
            bookTitle: bookTitle,
            chapterTitle: chapter.title,
            previousEN: previousParagraph?.en,
            previousZH: previousParagraph.flatMap { exactCached[$0.id] }
        )
    }
}

actor ChapterPrefetchWorker {
    private let database: AppDatabase
    private let registry: EngineRegistry

    init(database: AppDatabase, registry: EngineRegistry) {
        self.database = database
        self.registry = registry
    }

    func prefetch(chapter: ReaderChapter, config: EngineConfig, bookTitle: String? = nil) async {
        do {
            let cached = completeCachedTranslations(
                try await database.cachedTranslations(
                    chapterId: chapter.id,
                    preferredEngine: config.id,
                    preferredModel: config.model
                ),
                in: chapter
            )
            var exactCached = try await database.cachedTranslations(
                chapterId: chapter.id,
                engine: config.id,
                model: config.model
            )
            exactCached = completeCachedTranslations(exactCached, in: chapter)
            let missing = chapter.paragraphs.filter { cached[$0.id] == nil }
            guard !missing.isEmpty else {
                return
            }

            let engine = try registry.engine(for: config)
            for paragraph in missing {
                if let cachedZH = try await completeCachedTranslation(for: paragraph, database: database, config: config) {
                    exactCached[paragraph.id] = cachedZH
                    continue
                }

                let task = TranslationTask.paragraph(
                    text: paragraph.en,
                    context: paragraphContext(
                        for: paragraph,
                        in: chapter,
                        exactCached: exactCached,
                        bookTitle: bookTitle
                    )
                )
                var zh = ""
                for try await chunk in engine.translate([task], model: config.model) {
                    try Task.checkCancellation()
                    zh += chunk.text
                }
                if !zh.isEmpty,
                   ParagraphTranslationCompleteness.isComplete(source: paragraph.en, translation: zh) {
                    try await database.upsertTranslation(
                        Translation(
                            id: nil,
                            paragraphId: paragraph.id,
                            engine: config.id,
                            model: config.model,
                            zh: zh,
                            createdAt: Date()
                        )
                    )
                    exactCached[paragraph.id] = zh
                }
            }
        } catch {
            return
        }
    }

    private func paragraphContext(
        for paragraph: ReaderParagraph,
        in chapter: ReaderChapter,
        exactCached: [Int64: String],
        bookTitle: String?
    ) -> ParagraphContext {
        let previousParagraph = chapter.paragraphs.first { $0.ord == paragraph.ord - 1 }
        return ParagraphContext(
            bookTitle: bookTitle,
            chapterTitle: chapter.title,
            previousEN: previousParagraph?.en,
            previousZH: previousParagraph.flatMap { exactCached[$0.id] }
        )
    }
}

private enum ParagraphTranslationAttemptResult {
    case success(String)
    case failure(String)
    case cancelled
}

private enum ParagraphTranslationFailure: LocalizedError {
    case emptyStream
    case incomplete

    var errorDescription: String? {
        switch self {
        case .emptyStream:
            return "翻译流提前结束，本段未译"
        case .incomplete:
            return "翻译结果疑似不完整，本段未缓存"
        }
    }
}

private nonisolated enum ParagraphTranslationCompleteness {
    private static let sourceTerminalCharacters: Set<Character> = [".", "!", "?", "。", "！", "？", "”", "\"", "'", "’"]
    private static let translationTerminalCharacters: Set<Character> = [
        "。", "！", "？", "…", "”", "」", "』", "）", ")", ".", "!", "?", "\"", "'", "’",
    ]

    static func isComplete(source: String, translation: String) -> Bool {
        let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTranslation.isEmpty else {
            return false
        }

        guard requiresTerminalPunctuation(normalizedSource) else {
            return true
        }

        return normalizedTranslation.last.map(translationTerminalCharacters.contains) == true
    }

    private static func requiresTerminalPunctuation(_ source: String) -> Bool {
        guard source.count >= 80,
              let last = source.last else {
            return false
        }
        return sourceTerminalCharacters.contains(last)
    }
}

private nonisolated func completeCachedTranslations(_ cached: [Int64: String], in chapter: ReaderChapter) -> [Int64: String] {
    Dictionary(uniqueKeysWithValues: chapter.paragraphs.compactMap { paragraph in
        guard let zh = cached[paragraph.id],
              ParagraphTranslationCompleteness.isComplete(source: paragraph.en, translation: zh) else {
            return nil
        }
        return (paragraph.id, zh)
    })
}

private nonisolated func completeCachedTranslation(
    for paragraph: ReaderParagraph,
    database: AppDatabase,
    config: EngineConfig
) async throws -> String? {
    guard let zh = try await database.cachedTranslation(
        paragraphId: paragraph.id,
        engine: config.id,
        model: config.model
    ), ParagraphTranslationCompleteness.isComplete(source: paragraph.en, translation: zh) else {
        return nil
    }
    return zh
}

private extension EngineConfig {
    var displayName: String {
        switch id {
        case .openai:
            return "OpenAI"
        case .anthropic:
            return "Claude"
        case .deepseek:
            return "DeepSeek"
        }
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
