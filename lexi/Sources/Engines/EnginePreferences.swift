import Foundation

enum EnginePreferences {
    static func chapterConfig(database: AppDatabase?) async -> EngineConfig {
        await config(storageKey: "engine.default.chapter", database: database)
    }

    static func popupConfig(database: AppDatabase?) async -> EngineConfig {
        await config(storageKey: "engine.default.popup", database: database)
    }

    private static func config(storageKey: String, database: AppDatabase?) async -> EngineConfig {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        let engine = raw.flatMap(EngineID.init(rawValue:)) ?? .deepseek
        if let stored = try? await database?.engineConfig(for: engine) {
            return stored
        }
        return EngineConfig(
            id: engine,
            model: ReaderFixtureStore.defaultModel(for: engine),
            lastTestedOK: false,
            lastTestedAt: nil
        )
    }
}

extension Notification.Name {
    static let lexiEngineSettingsChanged = Notification.Name("lexi.engineSettingsChanged")
}
