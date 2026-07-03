import OSLog

nonisolated enum LexiLog {
    private static let subsystem = "com.lexi"

    private static let engine = Logger(subsystem: subsystem, category: "engine")
    private static let db = Logger(subsystem: subsystem, category: "db")
    private static let epub = Logger(subsystem: subsystem, category: "epub")
    private static let tts = Logger(subsystem: subsystem, category: "tts")

    static func engineError(_ message: String) {
        engine.error("\(message, privacy: .public)")
    }

    static func dbError(_ message: String) {
        db.error("\(message, privacy: .public)")
    }

    static func epubError(_ message: String) {
        epub.error("\(message, privacy: .public)")
    }

    static func ttsError(_ message: String) {
        tts.error("\(message, privacy: .public)")
    }
}
