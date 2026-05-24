import AVFoundation
import Foundation
import Observation

nonisolated enum ReadAloudPlaybackStatus: Equatable, Sendable {
    case idle
    case planning
    case preparingStyle
    case generating(String)
    case playing(String)
    case paused(String)
    case fallback(String)
    case error(String)

    var label: String {
        switch self {
        case .idle:
            return "朗读就绪"
        case .planning:
            return "准备朗读"
        case .preparingStyle:
            return "正在准备朗读风格…"
        case .generating(let range):
            return "正在生成 · \(range)"
        case .playing(let range):
            return "正在朗读 · \(range)"
        case .paused(let range):
            return "已暂停 · \(range)"
        case .fallback(let range):
            return "系统朗读 · \(range)"
        case .error(let message):
            return "朗读失败 · \(message)"
        }
    }

    var isActive: Bool {
        switch self {
        case .idle, .error:
            return false
        case .planning, .preparingStyle, .generating, .playing, .paused, .fallback:
            return true
        }
    }

    var canPause: Bool {
        if case .playing = self {
            return true
        }
        return false
    }

    var canResume: Bool {
        if case .paused = self {
            return true
        }
        return false
    }
}

@Observable
@MainActor
final class ReaderReadAloudController: NSObject {
    private let database: AppDatabase
    private let registry: TTSRegistry
    private let engineRegistry: EngineRegistry
    private let profileResolver: NarrationProfileResolving
    private let audioResolver: ReadAloudAudioResolving
    private let playerFactory: @MainActor (URL) -> ReaderAudioPlaying
    private let systemSpeaker: ReaderSystemSpeaking
    private var chunks: [ReadAloudChunk] = []
    private var currentIndex = 0
    private var generationTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var player: ReaderAudioPlaying?
    private var playerObserver: NSObjectProtocol?
    private var currentConfig = TTSProviderConfig.doubaoDefault

    private(set) var status: ReadAloudPlaybackStatus = .idle
    private(set) var language: TTSAudioLanguage = .source

    init(
        database: AppDatabase,
        registry: TTSRegistry = .shared,
        engineRegistry: EngineRegistry = .shared,
        profileResolver: NarrationProfileResolving? = nil,
        audioResolver: ReadAloudAudioResolving? = nil,
        playerFactory: (@MainActor (URL) -> ReaderAudioPlaying)? = nil,
        systemSpeaker: ReaderSystemSpeaking? = nil
    ) {
        self.database = database
        self.registry = registry
        self.engineRegistry = engineRegistry
        self.profileResolver = profileResolver ?? DefaultNarrationProfileResolver()
        self.audioResolver = audioResolver ?? DefaultReadAloudAudioResolver()
        self.playerFactory = playerFactory ?? { AVPlayerReaderAudioPlayer(url: $0) }
        self.systemSpeaker = systemSpeaker ?? AVSpeechReaderSystemSpeaker()
        super.init()
        self.systemSpeaker.onFinish = { [weak self] in
            self?.advanceAfterCurrentChunk()
        }
    }

    @MainActor deinit {
        stop()
    }

    var isPlaying: Bool {
        status.canPause
    }

    func start(
        book: ReaderBook,
        chapters: [ReaderChapter],
        chapter: ReaderChapter,
        snapshot: ChapterTranslationSnapshot,
        visibleParagraphId: Int64?,
        language requestedLanguage: TTSAudioLanguage,
        config: TTSProviderConfig,
        engineConfig: EngineConfig,
        forceRefreshProfile: Bool = false
    ) {
        stop()
        status = .planning
        language = requestedLanguage
        currentConfig = config
        let planned = ReadAloudChunkPlanner.chunks(
            for: chapter,
            snapshot: snapshot,
            language: requestedLanguage,
            startParagraphId: visibleParagraphId
        )
        guard !planned.isEmpty else {
            status = .error(
                ReadAloudChunkPlanner.unavailableReason(
                    for: requestedLanguage,
                    chapter: chapter,
                    snapshot: snapshot,
                    startParagraphId: visibleParagraphId
                ) ?? "当前没有可朗读内容"
            )
            return
        }

        chunks = planned
        currentIndex = 0
        prepareProfileAndPlay(
            book: book,
            chapters: chapters,
            currentChapter: chapter,
            engineConfig: engineConfig,
            forceRefreshProfile: forceRefreshProfile
        )
    }

    func pauseOrResume() {
        if status.canPause {
            player?.pause()
            if let chunk = chunks[safe: currentIndex] {
                status = .paused(chunk.displayRange)
            }
        } else if status.canResume {
            player?.play()
            if let chunk = chunks[safe: currentIndex] {
                status = .playing(chunk.displayRange)
            }
        }
    }

    func stop() {
        generationTask?.cancel()
        prefetchTask?.cancel()
        generationTask = nil
        prefetchTask = nil
        removePlayerObserver()
        player?.pause()
        player = nil
        systemSpeaker.stop()
        chunks = []
        currentIndex = 0
        status = .idle
    }

    func previousChunk() {
        guard currentIndex > 0 else {
            return
        }
        currentIndex -= 1
        playCurrentChunk()
    }

    func nextChunk() {
        guard currentIndex + 1 < chunks.count else {
            stop()
            return
        }
        currentIndex += 1
        playCurrentChunk()
    }

    func cancelForReaderTransition() {
        stop()
    }

    private func playCurrentChunk() {
        generationTask?.cancel()
        prefetchTask?.cancel()
        removePlayerObserver()
        player?.pause()
        systemSpeaker.stop()

        guard let chunk = chunks[safe: currentIndex] else {
            stop()
            return
        }

        status = .generating(chunk.displayRange)
        generationTask = Task { [database, registry, audioResolver, currentConfig] in
            do {
                let url = try await audioResolver.resolveAudioURL(
                    for: chunk,
                    database: database,
                    registry: registry,
                    config: currentConfig
                )
                guard !Task.isCancelled else {
                    return
                }
                playResolvedAudio(url, for: chunk)
                prefetchNextChunk()
            } catch is CancellationError {
                return
            } catch TTSProviderError.missingAPIKey, TTSProviderError.missingSpeaker {
                guard !Task.isCancelled else {
                    return
                }
                playSystemFallback(chunk)
            } catch {
                guard !Task.isCancelled else {
                    return
                }
                status = .error(error.localizedDescription)
            }
        }
    }

    private func prepareProfileAndPlay(
        book: ReaderBook,
        chapters: [ReaderChapter],
        currentChapter: ReaderChapter,
        engineConfig: EngineConfig,
        forceRefreshProfile: Bool
    ) {
        generationTask?.cancel()
        status = .preparingStyle
        generationTask = Task { [database, engineRegistry, profileResolver, currentConfig] in
            let profile = await profileResolver.profile(
                book: book,
                chapters: chapters,
                currentChapter: currentChapter,
                provider: currentConfig.provider,
                forceRefresh: forceRefreshProfile,
                database: database,
                engineConfig: engineConfig,
                engineRegistry: engineRegistry
            )
            guard !Task.isCancelled else {
                return
            }
            for index in chunks.indices {
                chunks[index].profile = profile
            }
            playCurrentChunk()
        }
    }

    private func playResolvedAudio(_ url: URL, for chunk: ReadAloudChunk) {
        removePlayerObserver()
        let nextPlayer = playerFactory(url)
        player = nextPlayer
        if let item = nextPlayer.currentItem {
            playerObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                guard let self else {
                    return
                }
                Task { @MainActor in
                    self.advanceAfterCurrentChunk()
                }
            }
        }
        nextPlayer.play()
        status = .playing(chunk.displayRange)
    }

    private func playSystemFallback(_ chunk: ReadAloudChunk) {
        systemSpeaker.speak(chunk.text)
        status = .fallback(chunk.displayRange)
    }

    private func advanceAfterCurrentChunk() {
        guard status.isActive else {
            return
        }
        nextChunk()
    }

    private func prefetchNextChunk() {
        guard let next = chunks[safe: currentIndex + 1] else {
            return
        }
        prefetchTask?.cancel()
        prefetchTask = Task { [database, registry, audioResolver, currentConfig] in
            _ = try? await audioResolver.resolveAudioURL(
                for: next,
                database: database,
                registry: registry,
                config: currentConfig
            )
        }
    }

}

nonisolated protocol ReadAloudAudioResolving: Sendable {
    func resolveAudioURL(
        for chunk: ReadAloudChunk,
        database: AppDatabase,
        registry: TTSRegistry,
        config: TTSProviderConfig
    ) async throws -> URL
}

nonisolated struct DefaultReadAloudAudioResolver: ReadAloudAudioResolving {
    func resolveAudioURL(
        for chunk: ReadAloudChunk,
        database: AppDatabase,
        registry: TTSRegistry,
        config: TTSProviderConfig
    ) async throws -> URL {
        let key = Self.audioCacheKey(for: chunk, config: config)
        if let record = try await database.audioCacheRecord(cacheKey: key.value),
           FileManager.default.fileExists(atPath: record.fileURL.path) {
            return record.fileURL
        }

        let provider = try registry.provider(for: config)
        let fileURL = try AudioCacheLocation.fileURL(cacheKey: key.value, format: config.format)
        var audio = Data()
        for try await audioChunk in provider.streamSpeech(TTSRequest(
            text: chunk.text,
            config: config,
            contextInstruction: chunk.profile?.ttsContextInstruction ?? "Read naturally with clear phrasing and expressive pacing."
        )) {
            try Task.checkCancellation()
            audio.append(audioChunk.data)
        }
        guard !audio.isEmpty else {
            throw TTSProviderError.invalidResponse
        }
        try audio.write(to: fileURL, options: .atomic)
        let now = Date()
        try await database.upsertAudioCacheRecord(AudioCacheRecord(
            cacheKey: key.value,
            bookId: chunk.bookId,
            chapterId: chunk.chapterId,
            paragraphStart: chunk.paragraphStart,
            paragraphEnd: chunk.paragraphEnd,
            language: chunk.language,
            provider: config.provider,
            resourceId: config.resourceId,
            speaker: config.speaker,
            speechRate: config.speechRate,
            profileHash: key.profileHash,
            textHash: key.textHash,
            fileURL: fileURL,
            byteCount: Int64(audio.count),
            durationSeconds: nil,
            createdAt: now,
            lastAccessedAt: now
        ))
        return fileURL
    }

    static func audioCacheKey(for chunk: ReadAloudChunk, config: TTSProviderConfig) -> TTSAudioCacheKey {
        TTSAudioCacheKey(
            bookId: chunk.bookId,
            chapterId: chunk.chapterId,
            paragraphStart: chunk.paragraphStart,
            paragraphEnd: chunk.paragraphEnd,
            language: chunk.language,
            provider: config.provider,
            resourceId: config.resourceId,
            speaker: config.speaker,
            speechRate: config.speechRate,
            profileHash: chunk.profile?.profileHash ?? "profile-none",
            textHash: TTSAudioCacheKey.makeTextHash(chunk.text)
        )
    }
}

private extension ReaderReadAloudController {
    func removePlayerObserver() {
        if let playerObserver {
            NotificationCenter.default.removeObserver(playerObserver)
            self.playerObserver = nil
        }
    }
}

@MainActor
protocol ReaderAudioPlaying: AnyObject, Sendable {
    var currentItem: AVPlayerItem? { get }
    func play()
    func pause()
}

@MainActor
private final class AVPlayerReaderAudioPlayer: ReaderAudioPlaying, @unchecked Sendable {
    private let player: AVPlayer

    init(url: URL) {
        player = AVPlayer(url: url)
    }

    var currentItem: AVPlayerItem? {
        player.currentItem
    }

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }
}

@MainActor
protocol ReaderSystemSpeaking: AnyObject, Sendable {
    var onFinish: (@MainActor @Sendable () -> Void)? { get set }
    func speak(_ text: String)
    func stop()
}

@MainActor
private final class AVSpeechReaderSystemSpeaker: NSObject, ReaderSystemSpeaking, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    var onFinish: (@MainActor @Sendable () -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

extension AVSpeechReaderSystemSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.onFinish?()
        }
    }
}

private extension Array {
    nonisolated subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
