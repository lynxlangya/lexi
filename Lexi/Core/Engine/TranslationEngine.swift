//
//  TranslationEngine.swift
//  Lexi
//
//  Created by Codex on 12/12/25.
//

import Foundation

enum TranslationEngineKind: String, Codable, Hashable {
    case free
    case openAICompatible
}

struct TranslationEngine: Identifiable, Codable, Hashable {
    let id: String
    var kind: TranslationEngineKind
    var displayName: String
    var baseURL: String?
    var apiKey: String?
    var model: String?
    var isCustom: Bool

    init(
        id: String,
        kind: TranslationEngineKind,
        displayName: String,
        baseURL: String? = nil,
        apiKey: String? = nil,
        model: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.isCustom = isCustom
    }

    var resolvedModel: String {
        model ?? id
    }

    static func free(id: String, displayName: String) -> TranslationEngine {
        TranslationEngine(id: id, kind: .free, displayName: displayName)
    }

    static func openAIModel(id: String, displayName: String) -> TranslationEngine {
        TranslationEngine(id: id, kind: .openAICompatible, displayName: displayName)
    }
}

