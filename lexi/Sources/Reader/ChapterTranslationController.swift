import Foundation
import Observation

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
    private var task: Task<Void, Never>?
    private var paragraphRetryTasks: [Int64: Task<Void, Never>] = [:]
    private var paragraphRetryTokens: [Int64: UUID] = [:]

    private(set) var selectedChapterId: Int64?
    private(set) var currentEngineConfig: EngineConfig
    private(set) var snapshots: [Int64: ChapterTranslationSnapshot] = [:]

    init(
        database: AppDatabase,
        engineConfig: EngineConfig,
        registry: EngineRegistry = .shared
    ) {
        self.database = database
        self.currentEngineConfig = engineConfig
        self.registry = registry
        self.prefetchWorker = ChapterPrefetchWorker(database: database, registry: registry)
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
                do {
                    snapshots[chapter.id]?.paragraphStates[paragraph.id] = .translating
                    reconcileChapterState(for: chapter)
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
                        snapshots[chapter.id]?.paragraphStates[paragraph.id] = .cached(zh)
                        reconcileChapterState(for: chapter)
                    }

                    if case .translating = snapshots[chapter.id]?.paragraphStates[paragraph.id] {
                        markTranslatingParagraphsAsError(
                            in: chapter,
                            candidates: Array(missing[missingIndex...]),
                            reason: "翻译流提前结束，本段未译"
                        )
                        reconcileChapterState(for: chapter)
                        return
                    }
                    exactCached[paragraph.id] = zh
                } catch is CancellationError {
                    return
                } catch let error as EngineError {
                    apply(error: error, to: chapter, translating: Array(missing[missingIndex...]))
                    return
                } catch {
                    apply(reason: error.localizedDescription, to: chapter, translating: Array(missing[missingIndex...]))
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
                    exactCached: exactCached,
                    bookTitle: bookTitle
                )
            )
            for try await chunk in engine.translate([task], model: config.model) {
                try Task.checkCancellation()
                zh += chunk.text
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
                snapshots[chapter.id]?.paragraphStates[paragraph.id] = .cached(zh)
                reconcileChapterState(for: chapter)
            }

            markTranslatingParagraphsAsError(
                in: chapter,
                candidates: [paragraph],
                reason: "翻译流提前结束，本段未译"
            )
            reconcileChapterState(for: chapter)
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
            if let zh = cached[paragraph.id] {
                snapshot.paragraphStates[paragraph.id] = .cached(zh)
            }
        }
        return snapshot
    }

    private func apply(error: EngineError, to chapter: ReaderChapter, translating: [ReaderParagraph]) {
        switch error {
        case .paragraphFailed(let index, let reason):
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
            case .translating:
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
            if case .translating = snapshots[chapter.id]?.paragraphStates[paragraph.id] {
                snapshots[chapter.id]?.paragraphStates[paragraph.id] = .error(reason)
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
            let cached = try await database.cachedTranslations(
                chapterId: chapter.id,
                preferredEngine: config.id,
                preferredModel: config.model
            )
            var exactCached = try await database.cachedTranslations(
                chapterId: chapter.id,
                engine: config.id,
                model: config.model
            )
            let missing = chapter.paragraphs.filter { cached[$0.id] == nil }
            guard !missing.isEmpty else {
                return
            }

            let engine = try registry.engine(for: config)
            for paragraph in missing {
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
                }
                if !zh.isEmpty {
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
