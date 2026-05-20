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

    var engineLabel: String {
        currentEngineConfig.displayName
    }

    func prepare(chapters: [ReaderChapter]) async {
        for chapter in chapters {
            do {
                var snapshot = try await cachedSnapshot(
                    for: chapter,
                    database: database,
                    config: currentEngineConfig
                )
                let cachedCount = chapter.paragraphs.filter { paragraph in
                    if case .cached = snapshot.paragraphStates[paragraph.id] {
                        return true
                    }
                    return false
                }.count
                snapshot.chapterState = cachedCount == chapter.paragraphs.count ? .cached : .idle
                snapshots[chapter.id] = snapshot
            } catch {
                snapshots[chapter.id] = ChapterTranslationSnapshot(chapterState: .error(error.localizedDescription))
            }
        }
    }

    func selectChapter(_ chapter: ReaderChapter, chapters: [ReaderChapter], prefetchCount: Int) {
        task?.cancel()
        selectedChapterId = chapter.id
        task = Task { [database, registry, currentEngineConfig] in
            await translateChapter(
                chapter,
                database: database,
                registry: registry,
                config: currentEngineConfig,
                force: false
            )

            guard !Task.isCancelled, prefetchCount > 0 else {
                return
            }

            let nextChapters = chapters
                .filter { $0.idx > chapter.idx }
                .prefix(prefetchCount)
            for nextChapter in nextChapters {
                await prefetchWorker.prefetch(chapter: nextChapter, config: currentEngineConfig)
            }
        }
    }

    func retryParagraph(_ paragraph: ReaderParagraph, in chapter: ReaderChapter) {
        task?.cancel()
        task = Task { [database, registry, currentEngineConfig] in
            await translateParagraph(
                paragraph,
                in: chapter,
                database: database,
                registry: registry,
                config: currentEngineConfig
            )
        }
    }

    func switchEngine(_ config: EngineConfig, chapter: ReaderChapter, chapters: [ReaderChapter], prefetchCount: Int) {
        currentEngineConfig = config
        selectChapter(chapter, chapters: chapters, prefetchCount: prefetchCount)
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
        force: Bool
    ) async {
        var missing: [ReaderParagraph] = []
        do {
            var snapshot = try await cachedSnapshot(for: chapter, database: database, config: config)
            let cachedCount = chapter.paragraphs.filter { paragraph in
                if case .cached = snapshot.paragraphStates[paragraph.id] {
                    return true
                }
                return false
            }.count

            if cachedCount == chapter.paragraphs.count, !force {
                snapshot.chapterState = .cached
                snapshots[chapter.id] = snapshot
                return
            }

            snapshot.chapterState = .translating(done: cachedCount)
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

            let engine = try registry.engine(for: config)
            var buffers: [Int: String] = [:]
            for try await chunk in engine.translate(missing.map(\.en), model: config.model) {
                try Task.checkCancellation()
                guard let paragraph = missing[safe: chunk.index] else {
                    continue
                }

                buffers[chunk.index, default: ""] += chunk.text
                let zh = buffers[chunk.index, default: ""]
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
                let done = translatedCount(for: chapter.id, total: chapter.paragraphs.count)
                snapshots[chapter.id]?.chapterState = done == chapter.paragraphs.count
                    ? .cached
                    : .translating(done: done)
            }

            let done = translatedCount(for: chapter.id, total: chapter.paragraphs.count)
            snapshots[chapter.id]?.chapterState = done == chapter.paragraphs.count
                ? .cached
                : .translating(done: done)
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
        config: EngineConfig
    ) async {
        do {
            snapshots[chapter.id]?.paragraphStates[paragraph.id] = .translating
            let engine = try registry.engine(for: config)
            var zh = ""
            for try await chunk in engine.translate([paragraph.en], model: config.model) {
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
            }

            let done = translatedCount(for: chapter.id, total: chapter.paragraphs.count)
            snapshots[chapter.id]?.chapterState = done == chapter.paragraphs.count
                ? .cached
                : .translating(done: done)
        } catch is CancellationError {
            return
        } catch {
            snapshots[chapter.id]?.paragraphStates[paragraph.id] = .error(error.localizedDescription)
            snapshots[chapter.id]?.chapterState = .error(error.localizedDescription)
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

    private func translatedCount(for chapterId: Int64, total: Int) -> Int {
        let count = snapshots[chapterId]?.paragraphStates.values.filter { state in
            if case .cached = state {
                return true
            }
            return false
        }.count ?? 0
        return min(count, total)
    }

    private func apply(error: EngineError, to chapter: ReaderChapter, translating: [ReaderParagraph]) {
        switch error {
        case .paragraphFailed(let index, let reason):
            let paragraphs = paragraphsForError(in: chapter, translating: translating)
            if let paragraph = paragraphs[safe: index] {
                snapshots[chapter.id]?.paragraphStates[paragraph.id] = .error(reason)
            } else {
                apply(reason: reason, to: chapter, translating: translating)
            }
            snapshots[chapter.id]?.chapterState = .error(reason)
        default:
            apply(reason: error.localizedDescription, to: chapter, translating: translating)
        }
    }

    private func apply(reason: String, to chapter: ReaderChapter, translating: [ReaderParagraph]) {
        for paragraph in paragraphsForError(in: chapter, translating: translating) {
            snapshots[chapter.id]?.paragraphStates[paragraph.id] = .error(reason)
        }
        snapshots[chapter.id]?.chapterState = .error(reason)
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
}

actor ChapterPrefetchWorker {
    private let database: AppDatabase
    private let registry: EngineRegistry

    init(database: AppDatabase, registry: EngineRegistry) {
        self.database = database
        self.registry = registry
    }

    func prefetch(chapter: ReaderChapter, config: EngineConfig) async {
        do {
            let cached = try await database.cachedTranslations(
                chapterId: chapter.id,
                preferredEngine: config.id,
                preferredModel: config.model
            )
            let missing = chapter.paragraphs.filter { cached[$0.id] == nil }
            guard !missing.isEmpty else {
                return
            }

            let engine = try registry.engine(for: config)
            var buffers: [Int: String] = [:]
            for try await chunk in engine.translate(missing.map(\.en), model: config.model) {
                try Task.checkCancellation()
                guard let paragraph = missing[safe: chunk.index] else {
                    continue
                }
                buffers[chunk.index, default: ""] += chunk.text
                try await database.upsertTranslation(
                    Translation(
                        id: nil,
                        paragraphId: paragraph.id,
                        engine: config.id,
                        model: config.model,
                        zh: buffers[chunk.index, default: ""],
                        createdAt: Date()
                    )
                )
            }
        } catch {
            return
        }
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
