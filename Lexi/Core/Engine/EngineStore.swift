//
//  EngineStore.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import Foundation

enum EngineStore {
    private static let customEnginesKey = "customEngines"

    static var builtInEngines: [TranslationEngine] {
        var engines: [TranslationEngine] = []
        engines.append(.free(id: "google", displayName: "Google"))

        for model in ModelOptions.openAIModels {
            engines.append(.openAIModel(id: model, displayName: model))
        }
        for model in ModelOptions.deepSeekModels {
            engines.append(.openAIModel(id: model, displayName: model))
        }
        return engines
    }

    static func allEngines() -> [TranslationEngine] {
        builtInEngines + loadCustomEngines()
    }

    static func normalizedEngineId(_ id: String) -> String {
        switch id {
        case "microsoft":
            return "google"
        default:
            return id
        }
    }

    static func engine(for id: String) -> TranslationEngine? {
        let normalizedId = normalizedEngineId(id)
        return allEngines().first { $0.id == normalizedId }
    }

    static func loadCustomEngines() -> [TranslationEngine] {
        guard let data = UserDefaults.standard.data(forKey: customEnginesKey) else {
            return []
        }
        return (try? JSONDecoder().decode([TranslationEngine].self, from: data)) ?? []
    }

    static func saveCustomEngines(_ engines: [TranslationEngine]) {
        let data = try? JSONEncoder().encode(engines)
        UserDefaults.standard.set(data, forKey: customEnginesKey)
    }
}
