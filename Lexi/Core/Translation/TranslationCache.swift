//
//  TranslationCache.swift
//  Lexi
//
//  Created by Codex on 05/19/26.
//

import CryptoKit
import Foundation

struct TranslationCacheKey: Hashable, Sendable {
    let textHash: String
    let sourceLanguage: String
    let targetLanguage: String
    let engineID: String
    let modelID: String
    let promptVersion: String

    init(
        textHash: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineID: String,
        modelID: String,
        promptVersion: String
    ) {
        self.textHash = textHash
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.engineID = engineID
        self.modelID = modelID
        self.promptVersion = promptVersion
    }

    init(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        engineID: String,
        modelID: String,
        promptVersion: String
    ) {
        self.init(
            textHash: Self.hash(text),
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            engineID: engineID,
            modelID: modelID,
            promptVersion: promptVersion
        )
    }

    static func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

protocol TranslationCache: Sendable {
    func get(_ key: TranslationCacheKey) async -> String?
    func set(_ key: TranslationCacheKey, value: String) async
}

actor InMemoryTranslationCache: TranslationCache {
    private var values: [TranslationCacheKey: String] = [:]

    func get(_ key: TranslationCacheKey) async -> String? {
        values[key]
    }

    func set(_ key: TranslationCacheKey, value: String) async {
        values[key] = value
    }
}
